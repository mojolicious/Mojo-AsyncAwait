package Mojo::AsyncAwait;

use Future::AsyncAwait 0.36;
use Mojo::Promise;

our $VERSION = '0.04';

sub import {
  my $caller = caller;
  Future::AsyncAwait->import_into($caller, future_class => 'Mojo::Promise');
}

1;


=encoding utf8

=head1 NAME

Mojo::AsyncAwait - An Async/Await implementation for Mojolicious

=head1 SYNOPSIS

  use Mojolicious::Lite -signatures;
  use Mojo::AsyncAwait;

  # same as
  use Mojolicious::Lite -signatures, -async_await;

=head1 DESCRIPTION

While this module used to contain an independent implementation of the async/await pattern, since L<Mojo::Bases> now has such a pattern built-in (provided by L<Future::AsyncAwait>) this module has been converted to a pass-through compatibitliy shim. If you want to just use the version from Mojo, go ahead and do so.

=head1 AUTHOR

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2020, L</AUTHOR>.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 SEE ALSO

L<Mojo::Promise>

L<Mojo::IOLoop>

L<MDN Async/Await|https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/async_function>

L<Future::AsyncAwait>

=cut

