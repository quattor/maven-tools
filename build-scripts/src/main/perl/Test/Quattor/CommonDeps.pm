package Test::Quattor::CommonDeps;

use strict;
use warnings;

=head1 NAME

Module with common perl modules from tests

=head1 DESCRIPTION

Module with common perl modules from tests. They are added here
in order to generate the correct dependencies on the C<perl-Test-Quattor>
package.

Only modules with dependencies provided by RH base repos and EPEL can be added
here.

=cut

use Class::Inspector;
use Taint::Runtime;
use Test::Deep;
use Test::MockObject::Extends;
use Test::NoWarnings;

1;
