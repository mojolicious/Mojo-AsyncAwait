use Mojo::Base -strict;

use Test::More;

use Mojo::AsyncAwait;
use Mojo::IOLoop;
use Mojo::Promise;

eval { await 42 };
like $@, qr'await may only be called from in async function';

sub answer {
  my $p = Mojo::Promise->new;
  Mojo::IOLoop->next_tick(sub{ $p->resolve(42) });
  return $p;
};

subtest 'eval' => sub {
  my $answer;
  async(sub {
    eval { $answer = await answer() };
  })->()->wait;

  is $answer, 42, 'got answer';
};

subtest 'deep call (good)' => sub {
  my $calls_answer = sub {
    return answer();
  };

  my ($answer, $err);
  my $async = async sub {
    $answer = await $calls_answer->();
  };
  $async->()->catch(sub{ $err = shift })->wait;

  is $answer, 42, 'got expected answer';
  ok !defined $err, 'this is the correct usage';
};

subtest 'deep call (bad)' => sub {
  my $calls_answer = sub {
    return await answer();
  };

  my ($answer, $err);
  my $async = async sub {
    $answer = $calls_answer->();
  };
  $async->()->catch(sub{ $err = shift })->wait;

  ok !defined $answer, 'should not get answer because of deep await call';
  like $err, qr'await may only be called from in async function', 'got expected error';
};


done_testing;

