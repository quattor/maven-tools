# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;

=pod

=head1 DESCRIPTION

Module to help mock the namespace

=head1 USAGE

E.g. to fake NCM:: namespace provided by the 'ncm' namespace

    BEGIN {
        use Test::Quattor::Namespace;
        INC_insert_namespace('ncm');
    }

    ...
    use NCM::Component
    ...

=cut

package Test::Quattor::Namespace;

use base 'Exporter';

our @EXPORT = qw(INC_insert_namespace);

use File::Basename qw(dirname);

=head2 Functions

=over

=item INC_insert_namespace

Setup @INC so NCM::Component is provided by Test::Quattor
Returns modified @INC as reference.

=cut

# 2 variables to track modifications (e.g. to reset it from other modules/scripts)
# inc_orig hold arrayref to copy of @INC when INC_insert_namespace was first called
our $inc_orig;

# $inc_history holds all @INCs ever modified
our $inc_history = [[@INC]];

sub INC_insert_namespace
{
    my $name = shift;
    my $filename = $INC{"Test/Quattor/Namespace.pm"};

    my $dir = dirname($filename);
    my $namespace_dir = "$dir/namespace/$name";

    if ($INC[0] ne $namespace_dir) {
        $inc_orig = [@INC] if (! defined $inc_orig);
        push (@$inc_history, [@INC]);

        # Insert in the beginning
        unshift(@INC, $namespace_dir);
    }

    return \@INC;
}

=pod

=back

=cut

1;
