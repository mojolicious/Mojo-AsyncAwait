use Mojo::Base -strict;

use Test::More;

use Mojo::IOLoop;
use Mojo::AsyncAwait;
use Sub::Util 'subname';

sub answer {
  my $p = Mojo::Promise->new;
  Mojo::IOLoop->timer(0.5 => sub { $p->resolve(42) });
  return $p;
}

my $tick = 0;
Mojo::IOLoop->recurring(0.1 => sub { $tick++ });

Mojo::IOLoop->timer(
  5 => sub {
    fail 'timeout';
    Mojo::IOLoop->stop;
  }
);

my $answer;
my $body = sub { $answer = await answer() };
async doit => $body;

my $package = __PACKAGE__;
is subname($body), "${package}::__ASYNCBODY__(doit)", 'correct body name';
is subname(\&doit), "${package}::doit", 'correct sub name';

doit()->wait;

is $answer, 42, 'got expected answer';
ok $tick > 2, 'got multiple ticks';

done_testing;


