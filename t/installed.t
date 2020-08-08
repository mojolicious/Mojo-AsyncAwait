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
async sub doit { $answer = await answer() }

my $package = __PACKAGE__;
is subname(\&doit), "${package}::doit", 'correct sub name';

doit()->wait;

is $answer, 42, 'got expected answer';
ok $ticker->() > 2, 'got multiple ticks';

done_testing;


