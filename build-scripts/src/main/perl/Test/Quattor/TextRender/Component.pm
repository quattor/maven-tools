# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}

use strict;
use warnings;

package Test::Quattor::TextRender::Component;

use File::Basename;

use Test::More;
use File::Path qw(mkpath);
use Cwd qw(getcwd);

use base qw(Test::Quattor::TextRender::Base);

=pod

=head1 NAME

Test::Quattor::TextRender::Component - Class for unittesting 
the TextRender usage (and TT in particular) in components.

=head1 DESCRIPTION

This class should be used to unittest CAF::TextRender usage
in components.

To be used as

    my $u = Test::Quattor::TextRender::Component->new(
        component => 'openneubla',
        )->test();

The tests require access to the C<template-library-core>
repository for using standard types in the schema files.

By default, the C<template-library-core> is expected to be in the 
same directory as the one this test is being ran from.
One can also specify the location via the C<QUATTOR_TEST_TEMPLATE_LIBRARY_CORE> 
environment variable.

=head2 Public methods

=over

=item new

Returns a new object, basepath is the default location
for component TT files (src/main/resources).

Accepts the following options

=over

=item component

The name of the component that these tests are part of.

=item usett

Force (or disable) the TT gather and verification test. E.g. disable when a 
builtin TextRender module is used. (By default, C<usett> is true).    

=back

=back

=cut

sub _initialize
{
    my ($self) = @_;

    ok($self->{component}, "Component name set " . ($self->{component} || ""));

    if (!defined($self->{usett})) {
        $self->{usett} = 1;
    }
    $self->verbose("usett $self->{usett}");

    my $srcpath    = getcwd() . "/src/main";
    my $targetpath = getcwd() . "/target";

    if (!$self->{basepath}) {
        $self->{basepath} = "$srcpath/resources";
    }

    # TT files are unrolled in the targetpath wrt the expected relpath
    # by the pom.xml (tt file under src/main/resources/data.tt for component
    # mycomp is put in target/share/templates/quattor/mycomp/data.tt)
    $self->{ttpath}      = "$targetpath/share/templates/quattor";
    $self->{relpath}     = $self->{component};
    $self->{includepath} = $self->{ttpath};

    if (!exists($self->{pannamespace})) {

        # the component has a rolled-out pan-namespace
        $self->{panunroll}     = 0;
        $self->{pannamespace}  = "components/$self->{component}";
        $self->{panpath}       = "$targetpath/pan/$self->{pannamespace}";
        $self->{namespacepath} = "$targetpath/pan";
    }

    ok($self->{pannamespace}, "Pannamespace set " .  ($self->{pannamespace} || "<undef>"));
    ok(-d $self->{panpath},   "Panpath directory " . ($self->{panpath} || "<undef>"));

    $self->{testspath} = $self->{basepath};

    $self->SUPER::_initialize();

}

1;
