package CoroX::PushState;

use strict;
use warnings;

use Carp ();
use Coro::State ();
use Scalar::Util ();

my $main = Coro::State->new;
$main->{desc} = 'CoroX::PushState main';

sub new {
  return bless {
    # LIFO stack of coroutines waiting to come back to
    # always has $main as the bottom of the stack
    stack => [$main],

    # Coroutines that are ostensible done but need someone to kill them
    clean => [],
  }, $_[0];
}

# push adds a coroutine to the stack and enters it
# when control returns to the original pusher, it will clean up
# any coroutines that are waiting to be cleaned up

my $isa = sub { Scalar::Util::blessed($_[0]) && $_[0]->isa($_[1]) };

sub push {
  my $self = shift;
  my ($stack, $clean) = @{$self}{qw/stack clean/};

  my $state;
  if ($_[0]->$isa('Coro::State')) {
    $state = shift;
  } else {
    my $desc = ref $_[0] ? undef : shift;
    $state = Coro::State->new(@_);
    $state->{desc} = $desc if defined $desc;
  }

  push @$stack, $state;
  $stack->[-2]->transfer($stack->[-1]);
  $_->cancel for @$clean;
  @$clean = ();
}

# pop pops the current coroutine off the stack. If given a callback, it calls
# a callback on it, otherwise, schedules it for cleanup. It then transfers to
# the next one on the stack. Note that it can't pop-and-return (which would
# make more sense) because any action on it must happen before control is
# transfered away from it

sub pop {
  my $self = shift;
  my ($stack, $clean) = @{$self}{qw/stack clean/};
  Carp::croak "Cannot leave the main thread"
    if $stack->[-1] == $main;
  my ($cb) = @_;
  my $current = pop @$stack;
  if ($cb) { $cb->($current)              }
  else     { CORE::push @$clean, $current }
  $current->transfer($stack->[-1]);
}

1;

