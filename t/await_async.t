use Mojo::Base -strict;

use Test::More;

use Mojo::IOLoop;
use Mojo::AsyncAwait;

sub double {
  my $in = shift;
  my $p  = Mojo::Promise->new;
  Mojo::IOLoop->timer(0.2 => sub { $p->resolve(2 * $in) });
  return $p;
}

async quad => sub {
  my $val = await double(shift);
  my $ret = await double($val);
  return $ret;
};

my $tick = 0;
Mojo::IOLoop->recurring(0.1 => sub { $tick++ });

my $answer;
Mojo::IOLoop->next_tick(
  async sub {
    $answer = await quad(3);
    Mojo::IOLoop->stop;
  }
);

Mojo::IOLoop->timer(
  5 => sub {
    fail 'timeout';
    Mojo::IOLoop->stop;
  }
);

Mojo::IOLoop->start;

is $answer, 12, 'got expected answer';
ok $tick > 2, 'got multiple ticks';

done_testing;


