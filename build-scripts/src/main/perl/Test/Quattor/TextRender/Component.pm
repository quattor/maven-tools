# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

package Test::Quattor::TextRender::Component;

use strict;
use warnings;

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

=item pannamespace

For modules that are almost components (like AII plugins), one can change the
C<pannamespace> (default is C<<components/<component> >>). (Use empty string to
indicate no namespace).

=item skippan

If C<skippan> is true, skip all pan related tests and checks.
This should only be needed in some rare case
(e.g. when testing TT files in other modules like CCM).
Default is not to skip any pan related tests.

=back

=back

=cut

# return default basepath
sub _default_basepath
{
    my $srcpath = getcwd() . "/src/main";
    return "$srcpath/resources";
}

sub _initialize
{
    my ($self) = @_;

    ok($self->{component}, "Component name set " . ($self->{component} || "<undef>"));

    if (!defined($self->{usett})) {
        $self->{usett} = 1;
    }
    $self->verbose("usett $self->{usett}");

    my $targetpath = getcwd() . "/target";

    $self->{basepath} = _default_basepath() if (!$self->{basepath});

    # TT files are unfolded in the targetpath wrt the expected relpath
    # by the pom.xml (tt file under src/main/resources/data.tt for component
    # mycomp is put in target/share/templates/quattor/mycomp/data.tt)
    $self->{ttpath}      = "$targetpath/share/templates/quattor";
    $self->{ttrelpath}     = $self->{component};
    $self->{ttincludepath} = $self->{ttpath};

    if($self->{skippan}) {
        $self->verbose("Skippan enabled");
        $self->{pannamespace} = '';
    } else {
        $self->{pannamespace}  = "components/$self->{component}"
            if ! defined($self->{pannamespace});

        $self->{namespacepath} = "$targetpath/pan"
            if ! defined($self->{namespacepath});

        $self->{panpath} = "$self->{namespacepath}/$self->{pannamespace}"
            if ! defined($self->{panpath});

        # the component has a unfolded pan-namespace
        $self->{panunfold} = 0 if ! defined($self->{panunfold});

        # pannamespace can be empty string
        ok(defined($self->{pannamespace}), "Pannamespace set " .
           ($self->{pannamespace} ? $self->{pannamespace} : "<undef>"));

        ok(-d $self->{panpath},
           "Panpath directory " . ($self->{panpath} || "<undef>"));
    }

    $self->{testspath} = $self->{basepath};

    $self->SUPER::_initialize();

}

1;
