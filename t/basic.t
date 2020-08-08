use Mojo::Base -strict;

use Test::More;

use Mojo::IOLoop;
use Mojo::AsyncAwait;

use Test::Lib;
use TestHelper;

sub double {
  my $in = shift;
  my $p  = Mojo::Promise->new;
  Mojo::IOLoop->timer(0.5 => sub { $p->resolve(2 * $in) });
  return $p;
}

my $ticker = ticker();

my $answer;
(async sub { $answer = await double(21) })->()->wait;

is $answer, 42, 'got expected answer';
ok $ticker->() > 2, 'got multiple ticks';

done_testing;

