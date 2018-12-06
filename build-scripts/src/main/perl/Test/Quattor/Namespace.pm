# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

package Test::Quattor::Namespace;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT = qw(INC_insert_namespace);

use File::Basename qw(dirname);

=pod

=head1 DESCRIPTION

Module to help mock the namespace

=head1 USAGE

E.g. to fake NCM:: namespace provided by the 'ncm' namespace

    BEGIN {
        use Test::Quattor::Namespace qw(ncm);
    }

    ...
    use NCM::Component
    ...

=cut


sub import
{
    my $class = shift;

    foreach my $namespace (@_) {
        INC_insert_namespace($namespace);
    }

    $class->SUPER::export_to_level(1, $class, @EXPORT);
}

=head2 Variables

=over

=item inc_orig

C<$inc_orig> holds arrayref to a copy of C<@INC> when
C<INC_insert_namespace> was first called.

=cut

our $inc_orig;

=item inc_history

C<$inc_history> is an arrayref with copy of all references of all C<@INC>'s modified

=cut

our $inc_history = [[@INC]];

=item ignore

Hashref with namespaces to ignore (if value is true) when C<INC_insert_namespace>
is used.

=cut

our $ignore = {};

=pod

=back

=head2 Functions

=over

=item INC_insert_namespace

Setup @INC so NCM::Component is provided by Test::Quattor
Returns modified @INC as reference.

=cut

sub INC_insert_namespace
{
    my $name = shift;

    my $filename = $INC{"Test/Quattor/Namespace.pm"};

    my $dir = dirname($filename);
    my $namespace_dir = "$dir/namespace/$name";

    if ((! $ignore->{$name}) && ($INC[0] ne $namespace_dir)) {
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
