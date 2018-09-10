use Test::More;
use Test::Mojo;

use Mojolicious::Lite;

my @hooks;

app->hook(
  after_build_tx => sub {
    my ($tx, $app) = @_;
    push @hooks, $tx;
  }
);

app->hook(
  around_dispatch => sub {
    my ($next, $c) = @_;
    push @hooks, $c;
    $next->();
    push @hooks, 'after_dispatch';
  }
);

app->hook(
  around_action => sub {
    my ($next, $c) = @_;
    push @hooks, 'before_action';
    my $res = $next->();
    push @hooks, $res;
    return $res;
  }
);

get '/' => sub {
  my $c       = shift;
  $c->render_later;
  my $promise = Mojo::Promise->new;
  Mojo::IOLoop->timer(1 => sub { $promise->resolve("hello world") });
$promise->then(sub {
    $c->render(text => shift);
  });
  return "all done";
};

my $t = Test::Mojo->new;
$t->get_ok('/')->status_is(200)->content_is("hello world");

#warn Data::Dumper::Dumper(\@hooks);
isa_ok($hooks[0], 'Mojo::Transaction');
isa_ok($hooks[1], 'Mojolicious::Controller');
is($hooks[2], 'before_action');
is($hooks[3], 'all done');
is($hooks[4], 'after_dispatch');

done_testing;
