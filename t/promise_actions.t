use Mojolicious::Lite;

use Scalar::Util 'blessed';
use Mojo::AsyncAwait;

use Test::More;
use Test::Mojo;

if (eval{ Mojolicious->VERSION(8.28); 1}) {
  plan skip_all => 'Mojolicious 8.28+ handles PromiseActions in core';
}

# specifically use development mode for the exception page
app->mode('development');

# manually install the guts of Mojolicious::Plugin::PromiseActions
# this tests that exception handling at the main coro can be accomplished from the hook
hook around_action => sub {
  my ($next, $c) = @_;
  my $res = $next->();
  if (blessed($res) && $res->can('then')) {
    my $tx = $c->render_later;
    $res->then(undef, sub { $c->reply->exception('XXX:' . pop) and undef $tx })->wait;
  }
  return $res;
};

get '/' => async sub { die "Argh\n" };

my $t = Test::Mojo->new;

$t->get_ok('/')
  ->status_is(500)
  ->text_is('#error' => "XXX:Argh\n");

done_testing;

