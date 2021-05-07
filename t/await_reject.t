use Mojo::Base -strict;

use Test::More;

use Mojo::AsyncAwait;
use Mojo::IOLoop;
use Mojo::Promise;

sub answer {
  my $p = Mojo::Promise->new;
  Mojo::IOLoop->next_tick(sub { $p->reject(42) });
  return $p;
}

subtest 'failure (traditional, with eval)' => sub {
  my ($answer, $eval_err, $async_func_err);
  async(sub {
    eval { $answer = await answer() };
    $eval_err = $@;
    if ($eval_err) {
      chomp $eval_err;
      die "$eval_err\n";
    }
  })->()->catch(sub { $async_func_err = shift; chomp $async_func_err; })
    ->wait;

  ok !defined $answer, 'no answer due to failure';
  is $eval_err, '42', 'got expected inner error "42"';

# variant for for Mojo::AsyncAwait 0.03 using Carp::croak() instead of die()
# like $eval_err, qr'42', "got somehow expected answer \"$eval_err\" (just \"42\" would be perfect)";
  is $async_func_err, '42', 'got expected outer error "42"';
};

subtest 'failure (traditional, improved - without eval)' => sub {
  my ($answer, $ref_err, $async_func_err);
  async(sub {
    $answer = await answer(), \$ref_err;
    die "$ref_err\n" if $ref_err;
  })->()->catch(sub { $async_func_err = shift; chomp $async_func_err })->wait;

  ok !defined $answer, 'no answer due to failure';
  is $ref_err,        '42', 'got expected inner error "42"';
  is $async_func_err, '42', 'got expected outer error "42"';
};

done_testing;

