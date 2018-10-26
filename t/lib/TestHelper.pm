package TestHelper;

use Mojo::Base -strict;

use Mojo::IOLoop;
use Test::More ();

use Exporter 'import';

our @EXPORT = (qw/ticker/);

sub ticker {
  my ($tick, $timeout) = @_;

  my $count = 0;

  my ($ticker, $timer);
  $ticker = Mojo::IOLoop->recurring(($tick // 0.1) => sub { $count++ });

  $timer = Mojo::IOLoop->timer(
    ($timeout // 5) => sub {
      Test::More::fail 'timeout';
      $timer = undef;
      Mojo::IOLoop->stop;
    }
  );

  return sub {
    defined($_) && Mojo::IOLoop->remove($_) for ($ticker, $timer);
    return $count;
  };
}

1;

