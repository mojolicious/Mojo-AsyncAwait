package Mojo::AsyncAwait;

use Mojo::Base -strict;

use Coro ();
use Mojo::Promise;
use Scalar::Util ();
use Carp();

use Exporter 'import';

our @EXPORT = (qw/async await/);

sub async {
  my $sub = shift;
  return sub {
    my @args = @_;
    Coro->new(sub{
      eval { $sub->(@args); 1 } or return $Coro::main->throw($@);
      $Coro::main->schedule_to;
    })->schedule_to;
  };
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

