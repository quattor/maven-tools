# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

package Test::Quattor::TextRender::Base;

use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Quattor::Panc qw(set_panc_includepath);
use Test::Quattor::ProfileCache qw(set_profile_cache_options
    get_profile_cache_dirs %DEFAULT_PROFILE_CACHE_DIRS
);

use Test::Quattor::TextRender::Suite;

use Cwd qw(getcwd abs_path);

use base qw(Test::Quattor::TextRender Exporter);

use Readonly;

Readonly our $TARGET_TT_DIR => "target/share/templates/quattor";

our @EXPORT = qw(mock_textrender);
our @EXPORT_OK = qw($TARGET_TT_DIR);

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

    if($self->{skippan}) {
        $self->verbose("Skippan enabled");
    } else {
        $self->test_gather_pan();

        # Set panc include dirs
        $self->make_namespace($self->{panpath}, $self->{pannamespace});
        set_panc_includepath($self->{namespacepath}, $self->get_template_library_core());
    }

    my $testspath = $self->{testspath};
    $testspath .= "/$self->{version}" if (defined($self->{version}));

    my $orig_dirs = get_profile_cache_dirs();
    my $cachedir = "$DEFAULT_PROFILE_CACHE_DIRS{cache}/$self->{pannamespace}";
    $cachedir .= "/$self->{version}" if (defined($self->{version}));

    set_profile_cache_options(cache => $cachedir);

    my $st   = Test::Quattor::TextRender::Suite->new(
        ttrelpath => $self->{ttrelpath},
        ttincludepath => $self->{ttincludepath},
        testspath   => "$testspath/tests",
    );

    $st->test();

    # TODO: reset it?
    #set_profile_cache_options(cache => $orig_dirs->{cache});
}


=pod

=head2 mock_textrender

An exported function that mocks C<CAF::TextRender>
to test usage of TT files during regular component use
in unittests. During this phase, C<CAF::TextRender> has to use
TT files that are being tested, not the ones installed.
(C<CAF::TextRender> has no easy way to do this to
avoid spreading TT files around).

It takes an optional argument C<includepath> and sets this
as the includepath of C<CAF::TextRender>. The default includepath
is C<target/share/templates/quattor>, where the TT files are
staged during testing via maven (use exported C<$TARGET_TT_DIR>).

To be used as

    use Test::Quattor::TextRender::Base;
    mock_textrender();

It returns the mock instance. (This is for convenience, you shouldn't
need this (except maybe to C<unmock_all>?). C<Test::MockModule>
keeps a cache of mocked instances, a new call would return the same
instance.)

=cut

sub mock_textrender
{
    my $includepath = shift;

    $includepath = [getcwd()."/$TARGET_TT_DIR"] if (! $includepath);

    my $mock = Test::MockModule->new('CAF::TextRender');
    $mock->mock('new', sub {
        my $init = $mock->original("new");
        my $trd = &$init(@_);
        $trd->{includepath} = $includepath;
        return $trd;
    });

    return $mock;
};

1;
