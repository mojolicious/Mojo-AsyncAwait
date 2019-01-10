package Mojo::AsyncAwait::Backend::Coro;
use Mojo::Base -strict;

use Carp ();
use Coro::State ();
use Mojo::Util;
use Mojo::Promise;
use Sub::Util ();

use Exporter 'import';

our @EXPORT = (qw/async await/);

my $main = Coro::State->new;
$main->{desc} = 'Mojo::AsyncAwait::Backend::Coro/$main';

# LIFO stack of coroutines waiting to come back to
# always has $main as the bottom of the stack
my @stack = ($main);

# Coroutines that are ostensible done but need someone to kill them
my @clean;

# _push adds a coroutine to the stack and enters it
# when control returns to the original pusher, it will clean up
# any coroutines that are waiting to be cleaned up

sub _push {
  push @stack, @_;
  $stack[-2]->transfer($stack[-1]);
  $_->cancel for @clean;
  @clean = ();
}

# _pop pops the current coroutine off the stack. If given a callback, it calls
# a callback on it, otherwise, schedules it for cleanup. It then transfers to
# the next one on the stack. Note that it can't pop-and-return (which would
# make more sense) because any action on it must happen before control is
# transfered away from it

sub _pop (;&) {
  Carp::croak "Cannot leave the main thread"
    if $stack[-1] == $main;
  my ($cb) = @_;
  my $current = pop @stack;
  if ($cb) { $cb->($current)       }
  else     { push @clean, $current }
  $current->transfer($stack[-1]);
}

sub async {
  my $body   = pop;
  my $opts   = _parse_opts(@_);
  my @caller = caller;

  my $subname  = "$caller[0]::__ASYNCSUB__";
  my $bodyname = "$caller[0]::__ASYNCBODY__";
  if (defined(my $name = $opts->{-name})) {
    $subname  = $opts->{-install} ? "$caller[0]::$name" : "$subname($name)";
    $bodyname .= "($name)";
  }
  my $desc = "declared at $caller[1] line $caller[2]";

  Sub::Util::set_subname($bodyname => $body)
    if Sub::Util::subname($body) =~ /::__ANON__$/;

  my $wrapped = sub {
    my @caller  = caller;
    my $promise = Mojo::Promise->new;
    my $coro    = Coro::State->new(sub {
      eval {
        BEGIN { $^H{'Mojo::AsyncAwait::Backend::Coro/async'} = 1 }
        $promise->resolve($body->(@_)); 1
      } or $promise->reject($@);
      _pop;
    }, @_);
    $coro->{desc} = "$subname called at $caller[1] line $caller[2], $desc";
    _push $coro;
    return $promise;
  };

  if ($opts->{-install}) {
    Mojo::Util::monkey_patch $caller[0], $opts->{-name} => $wrapped;
    return;
  }

  Sub::Util::set_subname $subname => $wrapped;
  return $wrapped;
}

# this prototype prevents the perl tokenizer from seeing await as an
# indirect method

sub await (*) {
  {
    # check that our caller is actually an async function
    no warnings 'uninitialized';
    my $level = 1;
    my ($caller, $hints) = (caller($level))[3, 10];

    # being inside of an eval is ok too
    ($caller, $hints) = (caller(++$level))[3, 10] while $caller eq '(eval)';

    Carp::croak 'await may only be called from in async function'
      unless $hints->{'Mojo::AsyncAwait::Backend::Coro/async'};
  }

  my $promise = Mojo::Promise->resolve($_[0]);

  my (@retvals, $err);
  _pop {
    my $current = shift;
    $promise->then(
      sub {
        @retvals = @_;
        _push $current;
      },
      sub {
        $err = shift;
        _push $current;
      }
    );
  };

  # "_push $current" in the above callback brings us here
  Carp::croak($err) if $err;
  return wantarray ? @retvals : $retvals[0];
}

sub _parse_opts {
  return {} unless @_;
  return {
    -name    => shift,
    -install => 1,
  } if @_ == 1;

  my %opts = @_;
  Carp::croak 'Cannot install a sub without a name'
    if $opts{-install} && !defined $opts{-name};

  return \%opts;
}

1;

=encoding utf8

=head1 NAME

Mojo::AsyncAwait::Backend::Coro - An Async/Await implementation for Mojolicious using Coro

=head1 SYNOPSIS

  use Mojolicious::Lite -signatures;
  use Mojo::AsyncAwait;

  get '/' => async sub ($c) {

    my $mojo = await $c->ua->get_p('https://mojolicious.org');
    my $cpan = await $c->ua->get_p('https://metacpan.org');

    $c->render(json => {
      mojo => $mojo->result->code,
      cpan => $cpan->result->code
    });
  };

  app->start;

=head1 DESCRIPTION

As the name suggests, L<Mojo::AsyncAwait::Backend::Coro> is an implementation
of the Async/Await pattern, using L<Mojo::Promise> and L<Coro>. See more at
L<Mojo::AsyncAwait>.

=head1 CAVEATS

This implementation relies on L<Coro> which does some very magical things to
the Perl interpreter. All caveats that apply to using L<Coro::State> apply to
this module as well.

Also note that while a L<Coro>-based implementation need not rely on L</await>
being called directly from an L</async> function, it is currently prohibitied
because it is likely that other/future implementations will rely on that
behavior and thus it should not be relied upon.

=head1 KEYWORDS

L<Mojo::AsyncAwait::Backend::Coro> provides two keywords (i.e. functions), both
exported by default. They are re-exported by L<Mojo::AsyncAwait> if it is the
chosen implementation.

=head2 async

  my $sub = async sub { ... };

The async keyword wraps a subroutine as an asynchronous subroutine which is
able to be suspended via L</await>. The return value(s) of the subroutine, when
called, will be wrapped in a L<Mojo::Promise>.

The async keyword must be called with a subroutine reference, which will be the
body of the async subroutine.

Note that the returned subroutine reference is not invoked for you.
If you want to immediately invoke it, you need to so manually.

  my $promise = async(sub{ ... })->();

If called with a preceding name, the subroutine will be installed into the current package with that name.

  async installed_sub => sub { ... };
  installed_sub();

If called with key-value arguments starting with a dash, the following options are available.

=over

=item -install

If set to a true value, the subroutine will be installed into the current package.
Default is false.
Setting this value to true without a C<-name> is an error.

=item -name

If C<-install> is false, this is a diagnostic name to be included in the subname for debugging purposes.
This name is seen in diagnostic information, like stack traces.

  my $named_sub = async -name => my_name => sub { ... };
  $named_sub->();

Otherwise this is the name that will be installed into the current package.

=back

Therefore, passing a bare name as is identical to setting both C<-name> and C<< -install => 1 >>.

  async -name => installed_sub, -install => 1 => sub { ... };
  installed_sub();

If the subroutine is installed, whether by passing a bare name or the C<-install> option, nothing is returned.
Otherwise the return value is the wrapped async subroutine reference.

=head2 await

  my $tx = await Mojo::UserAgent->new->get_p('https://mojolicious.org');
  my @results = await (async sub { ...; return @async_results })->();

The await keyword suspends execution of an async sub until a promise is
fulfilled, returning the promise's results. In list context all promise results
are returned. For ease of use, in scalar context the first promise result is
returned and the remainder are discarded.

If the value passed to await is not a promise (defined as having a C<then>
method), it will be wrapped in a Mojo::Promise for consistency. This is mostly
inconsequential to the user.

Note that await can only take one promise as an argument. If you wanted to
await multiple promises you probably want L<Mojo::Promise/all> or less likely
L<Mojo::Promise/race>.

  my $results = await Mojo::Promise->all(@promises);

=head1 SEE ALSO

L<Mojo::Promise>, L<Mojo::IOLoop>, L<Coro>, L<Coro::State>

=cut
