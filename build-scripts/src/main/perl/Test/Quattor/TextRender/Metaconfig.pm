# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}

use strict;
use warnings;

package Test::Quattor::TextRender::Metaconfig;

use File::Basename;

use Test::More;
use Test::Quattor::Panc qw(set_panc_includepath);

use Test::Quattor::TextRender::Suite;

use File::Path qw(mkpath);
use Cwd qw(getcwd abs_path);

use base qw(Test::Quattor::TextRender);

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

=head2 Public methods

=over

=item new

Returns a new object, basepath is the default location
for metaconfig-unittests.

Accepts the following options

=over

=item service

The name of the service (the service is a subdirectory of the basepath).

=item version

If a specific version is to be tested (undef assumes no version).

=back

=back

=cut

sub _initialize
{
    my ($self) = @_;

    if (!$self->{basepath}) {
        $self->{basepath} = getcwd() . "/src/main/metaconfig";
    }
    ok($self->{service}, "service $self->{service} defined for ttpath");

    # derive ttpath from service
    $self->{ttpath} = "$self->{basepath}/$self->{service}";

    $self->{panpath}      = "$self->{ttpath}/pan";
    $self->{pannamespace} = "metaconfig/$self->{service}";

    if (!$self->{namespacepath}) {
        my $dest = getcwd() . "/target/pan";
        if (!-d $dest) {
            mkpath($dest)
        }
        $self->{namespacepath} = $dest;
    }

    $self->SUPER::_initialize();

}

#
# Return path to template-library-core to allow "include 'pan/types';"
#
sub get_template_library_core
{
    # only for logging
    my $self = shift;

    my $tlc = $ENV{QUATTOR_TEST_TEMPLATE_LIBRARY_CORE};
    if ($tlc && -d $tlc) {
        $self->verbose(
            "template-library-core path $tlc set via QUATTOR_TEST_TEMPLATE_LIBRARY_CORE");
    } else {

        # TODO: better guess?
        my $d = "../template-library-core";
        if (-d $d) {
            $tlc = $d;
        } elsif (-d "../$d") {
            $tlc = "../$d";
        } else {
            $self->error("no more guesses for template-library-core path");
        }
    }
    if ($tlc) {
        $tlc = abs_path($tlc);
        $self->verbose("template-library-core path found $tlc");
    } else {
        $self->error(
            "No template-library-core path found (set QUATTOR_TEST_TEMPLATE_LIBRARY_CORE?)");
    }
    return $tlc;
}

=pod

=head2 test

Run all unittests to validate a set of templates. 

=cut

sub test
{
    my ($self) = @_;

    $self->test_gather_tt();
    $self->test_gather_pan();

    # Set panc include dirs
    $self->make_namespace($self->{panpath}, $self->{pannamespace});
    set_panc_includepath($self->{namespacepath}, $self->get_template_library_core);

    my $testspath = "$self->{basepath}/$self->{service}";
    $testspath .= "/$self->{version}" if (exists($self->{version}));

    my $base = getcwd() . "/src/test/resources";
    my $st   = Test::Quattor::TextRender::Suite->new(
        includepath => dirname($self->{basepath}),    # metaconfig relpath
        testspath   => "$testspath/tests",
    );

    $st->test();

}

1;
