use Mojo::Base -strict;

use Test::More;

use Mojo::AsyncAwait;
use Future;
$Mojo::AsyncAwait::PROMISE_CLASS = 'Future';
*Future::resolve = \&Future::done;
*Future::reject  = \&Future::fail;

sub double {
  my $in = shift;
  my $p  = Mojo::Promise->new;
  Mojo::IOLoop->timer(0.5 => sub { $p->resolve(2 * $in) });
  return $p;
}

my $tick = 0;
Mojo::IOLoop->recurring(0.1 => sub { $tick++ });

my $answer;
async(sub { 
  $answer = await double(21);
  Mojo::IOLoop->stop;
})->();

Mojo::IOLoop->timer(
  5 => sub {
    fail 'timeout';
    Mojo::IOLoop->stop;
  }
);

Mojo::IOLoop->start;

is $answer, 42, 'got expected answer';
ok $tick > 2, 'got multiple ticks';

done_testing;


