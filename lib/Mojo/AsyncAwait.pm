package Mojo::AsyncAwait;
use Mojo::Base -strict;

use Carp();
use Coro::State ();
use Mojo::Util;
use Mojo::Promise;
use Scalar::Util ();

use Exporter 'import';

our @EXPORT = (qw/async await/);

my $main = Coro::State->new;
$main->{desc} = 'Mojo::AsyncAwait/$main';

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
  my $sub     = pop;
  my $name    = shift;
  my $wrapped = sub {
    my $promise = Mojo::Promise->new;
    _push(Coro::State->new(sub {
      eval { $promise->resolve($sub->(@_)); 1 } or $promise->reject($@);
      _pop;
    }, @_));
    return $promise;
  };
  if ($name && !defined wantarray) {
    my $caller = caller;
    Mojo::Util::monkey_patch $caller, $name => $wrapped;
  }
  return $wrapped;
}

sub await {
  my $promise = shift;
  $promise = Mojo::Promise->new->resolve($promise)
    unless Scalar::Util::blessed($promise) && $promise->can('then');

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

1;

=encoding utf8

=head1 NAME

Mojo::AsyncAwait - An async/await implementation for Mojolicious

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

Async/await is a language-independent pattern that allows nonblocking
asynchronous code to be structured simliarly to blocking code. This is done by
allowing execution to be suspended by the await keyword and returning once the
promise passed to await has been fulfilled.

This pattern simplies the use of both promises and nonblocking code in general
and is therefore a very exciting development for writing asynchronous systems.

=head1 CAVEATS

First and foremost, this is all a little bit crazy. Please consider carefully
before using this code in production.

While many languages have async/await as a core language feature, currently in
Perl we must rely on modules that provide the mechanism of suspending and
resuming execution.

The default implementation relies on L<Coro> which does some very magical
things to the Perl interpreter. Other less magical implementations are in the
works however none are available yet. In the future if additional
implementations are available, this module might well be made pluggable. Please
do not rely on the L<Coro> being the implmementation of choice.

Also note that while the L<Coro>-based implementation does not rely on L</await>
being called directly from an L</async> function, it is currently not
prohibitied. Other implementations might rely on that behavior and thus it
should not be relied upon.

=head1 KEYWORDS

L<Mojo::AsyncAwait> provides two keywords (i.e. functions), both exported by
default.

=head2 async

  my $sub = async sub { ... };

The async keyword wraps a subroutine as an asynchronous subroutine which is
able to be suspended via L</await>. The return value(s) of the subroutine, when
called, will be wrapped in a L<Mojo::Promise>.

The async keyword must be called with a subroutine reference. The returned
value is the wrapped asynchronous subroutine reference.

The async keyword may also be used to install an asynchronous named subroutine
into the caller. This is done by calling async with two arguments, a name and a
subroutine reference.

  async named_sub => sub { ... };
  named_sub();

=head2 await

  my $tx = await +Mojo::UserAgent->new->get_p('https://mojolicious.org');
  my @results = await async sub { ...; return @async_results };

The await keyword suspends execution of an async sub until a promise is
fulfilled, returning the promise's results. In list context all promise results
are returned. For ease of use, in scalar context the first promise result is
returned and the remainder are discarded.

If the value passed to await is not a promise (defined as having a C<then>
method>), it will be wrapped in a Mojo::Promise for consistency. This is mostly
inconsequential to the user.

Note: An unfortunate conflict with the Perl parser sometimes causes it to see
the await keyword as an indirect object call on the promise. To avoid this, if
necessary, either call with parentheses C<await($promise)> or with a unary plus
operator C<await +$promise>. The CPAN module L<indirect> may help spot these
situations at compile time rather than runtime.

=head1 AUTHORS

Joel Berger <joel.a.berger@gmail.com>

Marcus Ramberg <mramberg@cpan.org>

=head1 CONTRIBUTORS

Sebastian Riedel <kraih@mojolicious.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018, L</AUTHORS> and L</CONTRIBUTORS>.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 SEE ALSO

L<https://github.com/mojolicious/mojo>, L<Mojolicious::Guides>,
L<https://mojolicious.org>.

TODO

=cut
