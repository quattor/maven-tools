# ${license-info}
# ${developer-info}
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
the templates in ncm-metaconfig and components.

Refer to the specialized Test::Quattor::TextRender::Metaconfig and 
Test::Quattor::TextRender::Component for actual usage.

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
    set_panc_includepath($self->{namespacepath}, $self->get_template_library_core());

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
