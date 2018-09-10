package Mojo::AsyncAwait;
use Mojo::Base -strict;

use Carp();
use Coro ();
use Mojo::Util;
use Mojo::Promise;
use Scalar::Util ();

use Exporter 'import';

our @EXPORT = (qw/async await/);

sub async {
  my $sub     = pop;
  my $name    = shift;
  my $wrapped = sub {
    Coro->new(
      sub {
        eval { $sub->(@_); 1 } or return $Coro::main->throw($@);
        $Coro::main->schedule_to;
      },
      @_
    )->schedule_to;
  };
  if ($name) {
    my $caller = caller;
    Mojo::Util::monkey_patch $caller, $name => $wrapped;
  }
  return $wrapped;
}

sub await {
  my $promise = shift;
  $promise = Mojo::Promise->new->resolve($promise)
    unless Scalar::Util::blessed($promise) && $promise->can('then');

  my $current = $Coro::current;
  my ($retval, $err);
  $promise->then(
    sub {
      $retval = shift;
      $current->schedule_to;
    },
    sub {
      $err = shift;
      $current->schedule_to;
    }
  );

  $Coro::main->schedule_to;
  Carp::croak($err) if $err;
  return $retval;
}

1;

=encoding utf8

=head1 NAME

Mojo::AsyncAwait - Async/Await using Coro and with a Mojo flourish

=head1 SYNOPSIS


  use Mojolicious::Lite;
  use Mojo::AsyncAwait;

  get('/' => async sub {
    my $c = shift;
    $c->render(text=> "Mojo front page is ".await($c->ua->get_p("mojolicious.org"))->res->headers->content_length);
  });


=head1 DESCRIPTION

=head1 ATTRIBUTES

=head1 METHODS

=head2 async

=head2 await

=head1 AUTHORS

Joel Berger <joel.a.berger@gmail.com>

Marcus Ramberg <mramberg@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008-2018, Joel A Berger and others.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

TODO

=head1 SEE ALSO

L<https://github.com/kraih/mojo>, L<Mojolicious::Guides>,
L<https://mojolicious.org>.

TODO

=cut
