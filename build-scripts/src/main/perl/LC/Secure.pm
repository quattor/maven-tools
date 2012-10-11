=pod

=head1 Description

Fake C<LC::Secure>

Stub for allowing test scripts to access the C<PATH>. The
C<LC::Secure> module defines a hardcoded PATH, which is excellent for
security, but sucks for testability because it may prevent us from
finding the Pan compiler.

Since we want it in production, but not in tests, we provide a test stub here.

=cut

package LC::Secure;

use strict;
use warnings;
use parent 'Exporter';

our @EXPORT_OK=qw(environment);

sub environment{}

1;
