
# Mojo::AsyncAwait

  An implementation of `async`/`await` for
  [Mojolicious](https://mojolicious.org) with an initial default implementation
  based on [Coro](https://metacpan.org/pod/Coro).

```perl
use Mojolicious::Lite -signatures;
use Mojo::AsyncAwait;

get '/' => async sub ($c) {

  my $mojo = await $c->ua->get_p('https://mojolicious.org');
  my $cpan = await $c->ua->get_p('https://metacpan.org');

  $c->render(json => {
    mojo => $mojo->result->code,
    cpan => $cpan->result->code
  });
};

app->start;
```

## Installation

  All you need is a one-liner, it takes less than a minute.

    $ curl -L https://cpanmin.us | perl - -M https://cpan.metacpan.org -n Mojo::AsyncAwait

  We recommend the use of a [Perlbrew](http://perlbrew.pl) environment.
