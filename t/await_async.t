use Mojo::Base -strict;

use Test::More;

use Mojo::IOLoop;
use Mojo::AsyncAwait;

use Test::Lib;
use TestHelper;

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

my $ticker = ticker();

my $answer;
async(sub { $answer = await quad(3) })->()->wait;

is $answer, 12, 'got expected answer';
ok $ticker->() > 2, 'got multiple ticks';

done_testing;


