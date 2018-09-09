use Mojo::Base -strict;

use Test::More;

use Mojo::IOLoop;
use Mojo::AsyncAwait;

sub answer {
  my $p = Mojo::Promise->new;
  Mojo::IOLoop->timer(0.5 => sub { $p->resolve(42) });
  return $p;
}

my $tick = 0;
Mojo::IOLoop->recurring(0.1 => sub { $tick++ });

my $answer;
async doit => sub {
  $answer = await answer();
  Mojo::IOLoop->stop;
};
Mojo::IOLoop->next_tick(\&doit);

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


