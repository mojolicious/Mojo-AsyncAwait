use Mojo::Base -strict;

use Test::More;

use Mojo::IOLoop;
use Mojo::AsyncAwait;

sub double {
  my $in = shift;
  return 2 * $in;
}

my $answer;
async(sub { $answer = await double(21) })->()->wait;

Mojo::IOLoop->timer(
  5 => sub {
    fail 'timeout';
    Mojo::IOLoop->stop;
  }
);

is $answer, 42, 'got expected answer';

done_testing;

