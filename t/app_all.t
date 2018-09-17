use Mojolicious::Lite;
use Mojo::Promise;
use Mojo::AsyncAwait;

use Test::More;
use Test::Mojo;

# N.B. this test tests the case from
# https://mojolicious.org/perldoc/Mojolicious/Guides/Cookbook#Synchronizing-non-blocking-operations
# substituting $external in place of calling out to metacpan

my $external = Mojolicious->new;
app->ua->server->app($external);
$external->routes->get('/x' => {text => 'X'});
$external->routes->get('/y' => {text => 'Y'});

get '/' => async sub {
  my $c = shift;

  my $x = $c->ua->get_p('/x');
  my $y = $c->ua->get_p('/y');

  # Render a response once both promises have been resolved
  my ($got_x, $got_y) = await +Mojo::Promise->all($x, $y);

  $c->render(json => {
    x => $got_x->[0]->result->text,
    y => $got_y->[0]->result->text,
  });
};

my $t = Test::Mojo->new;
$t->get_ok('/')
  ->status_is(200)
  ->json_is({x => 'X', y => 'Y'});

done_testing;

