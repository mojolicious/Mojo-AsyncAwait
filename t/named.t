use Mojo::Base -strict;

use Test::More;

use Mojo::IOLoop;
use Mojo::AsyncAwait;
use Sub::Util 'subname';

use Test::Lib;
use TestHelper;

sub answer {
  my $p = Mojo::Promise->new;
  Mojo::IOLoop->timer(0.5 => sub { $p->resolve(42) });
  return $p;
}

my $ticker = ticker();

my $answer;
my $body = sub { $answer = await answer() };
my $doit = async -name => doit => $body;

my $package = __PACKAGE__;
is subname($body), "${package}::__ASYNCBODY__(doit)", 'correct body name';
is subname($doit), "${package}::__ASYNCSUB__(doit)", 'correct sub name';

$doit->()->wait;

is $answer, 42, 'got expected answer';
ok $ticker->() > 2, 'got multiple ticks';

done_testing;


