# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}

use strict;
use warnings;

package Test::Quattor::TextRender::Base;

use Test::More;
use Test::Quattor::Panc qw(set_panc_includepath);

use Test::Quattor::TextRender::Suite;

use Cwd qw(getcwd abs_path);

use base qw(Test::Quattor::TextRender);

=pod

=head1 NAME

Test::Quattor::TextRender::Base - Base class for unittesting 
the templates in nmc-metaocnifg and components.

Refer to the specialized Test::Quattor::TextRender::Metaconfig and 
Test::Quattor::TextRender::Component for actual usage.

=head2 get_template_library_core

Return path to template-library-core to allow "include 'pan/types';" 
and friends being used in the templates (in particular the schema).

By default, the C<template-library-core> is expected to be in the 
same directory as the one this test is being ran from.
One can also specify the location via the C<QUATTOR_TEST_TEMPLATE_LIBRARY_CORE> 
environment variable.

=cut

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
        $self->notok(
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

    if ($self->{usett}) {
        $self->test_gather_tt();
    } else {
        $self->info("TT gather and verification test disabled");
    };

    $self->test_gather_pan();

    # Set panc include dirs
    $self->make_namespace($self->{panpath}, $self->{pannamespace});
    set_panc_includepath($self->{namespacepath}, $self->get_template_library_core);

    my $testspath = $self->{testspath};
    $testspath .= "/$self->{version}" if (exists($self->{version}));

    my $base = getcwd() . "/src/test/resources";
    my $st   = Test::Quattor::TextRender::Suite->new(
        ttrelpath => $self->{ttrelpath},
        ttincludepath => $self->{ttincludepath},
        testspath   => "$testspath/tests",
    );

    $st->test();

}

1;
