# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

package Test::Quattor::TextRender::Metaconfig;

use strict;
use warnings;

use File::Basename;

use Test::More;
use File::Path qw(mkpath);
use Cwd qw(getcwd);

use base qw(Test::Quattor::TextRender::Base);

=pod

=head1 NAME

Test::Quattor::TextRender::Metaconfig - Class for unittesting
the ncm-metaconfig services and their templates.

=head1 DESCRIPTION

This class should be used to unittest ncm-metaconfig
services and their templates.

To be used as

    my $u = Test::Quattor::TextRender::Metaconfig->new(
        service => 'logstash',
        version => '1.2',
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
for metaconfig-unittests (src/main/metaconfig).

Accepts the following options

=over

=item service

The name of the service (the service is a subdirectory of the basepath).

=item version

If a specific version is to be tested (undef assumes no version).

=item usett

Force (or disable) the TT gather and verification test. E.g. disable when a
builtin TextRender module is used. (By default, C<usett> is true).

=back

=back

=cut

sub _initialize
{
    my ($self) = @_;

    if(! defined($self->{usett})) {
        $self->{usett} = 1;
    }
    $self->verbose("usett $self->{usett}");

    if (!$self->{basepath}) {
        $self->{basepath} = getcwd() . "/src/main/metaconfig";
    }
    ok($self->{service}, "service $self->{service} defined for ttpath");

    # derive ttpath from service
    $self->{ttpath} = "$self->{basepath}/$self->{service}";

    $self->{panpath}      = "$self->{ttpath}/pan";
    $self->{pannamespace} = "metaconfig/$self->{service}";

    if (!$self->{namespacepath}) {
        $self->{namespacepath} = $self->make_target_pan_path();
    }

    # Fix TextRender relpath and includepath
    $self->{ttrelpath} = 'metaconfig';
    $self->{ttincludepath} = dirname($self->{basepath});

    $self->{testspath} = "$self->{basepath}/$self->{service}";

    # Force skippan disabled.
    $self->{skippan} = 0;

    $self->SUPER::_initialize();

}

1;
