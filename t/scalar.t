use Mojo::Base -strict;

use Test::More;

use Mojo::IOLoop;
use Mojo::AsyncAwait;

use Test::Lib;
use TestHelper;

sub double {
  my $in = shift;
  return 2 * $in;
}

my $ticker = ticker(0);

my $answer;
(async sub { $answer = await double(21) })->()->wait;

is $answer, 42, 'got expected answer';
ok $ticker->(), 'got at least one tick';

done_testing;

