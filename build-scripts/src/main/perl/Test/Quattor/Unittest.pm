# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

package Test::Quattor::Unittest;

use strict;
use warnings;

=pod

=head1 NAME

Test::Quattor::Unittest - Baseline unittest module.

=head1 DESCRIPTION

This is a class to trigger basic unittests.
Should be used as follows:

    use Test::Quattor::Unittest;

Adding the test is as simple as
    echo 'use Test::Quattor::Unittest;' > 00-tqu.t

=head1 FUNCTIONS

=over

=cut

use parent qw(Test::Quattor::Object);
use Config::Tiny;
use Readonly;
use Test::More;
use Cwd qw(getcwd);

# do_test boolean indicates that tests are run by import
# Only relevant when unittesting this package itself,
# by passing C<notest> on import.
my $do_test = 1;

# This is the very last thing to do
# Defined before any other END definitions in imported packages;
# as to always run as last, even after the END from e.g. NoWarnings
END {
    done_testing() if $do_test;
}

use Test::Quattor::Doc;
use Test::Quattor::Critic;
use Test::Quattor::Tidy;
use Test::Quattor::ProfileCache qw(set_json_typed);
use Test::Quattor::TextRender::Component;
set_json_typed();

Readonly::Array our @TESTS => qw(load doc tt critic tidy);

# When changing, also change the pod in read_cfg
Readonly our $CFG_FILENAME => 'tqu.cfg';
Readonly our $DEFAULT_CFG => <<'EOF';
[load]
enable = 1

[doc]
enable = 1

[tt]
enable = 1

[critic]
enable = 1

[tidy]
enable = 1

EOF

=item import

On import, run the tests.

Pass C<notest> to disable automatic testing
(only useful when testing this code).

Pass C<nopod> to set the C<nopodflag> (for C<doc> test)
when testing (is ignored when C<notest> is passed).

=cut

sub import
{
    my $class = shift;

    $do_test = ! grep {m/notest/} @_;
    if ($do_test) {
        my $inst = $class->new();
        $inst->{nopodflag} = (grep {m/nopod/} @_) ? 1 : 0;
        $inst->test();
    };
}

=pod

=back

=head1 METHODS

=over

=item new

No options are required/supported

=cut

sub _initialize
{

    my ($self) = shift;

    # Going to try to guess who i am
    my $cwd = getcwd();
    if ($cwd =~ m{/ncm-(\w+)/?}) {
        $self->{component} = $1;
    }
}

=item read_cfg

Read default config followed by optional configfile C<tqu.cfg> and optional
variable C<$main::TQU>.

Variable can be defined in main test as follows

    BEGIN {
        our $TQU = <<'EOF';
    ...
    EOF
    }

Every test section has at least the C<enable> option,
set to true by default.
For all other options, read the respective method
documentation.

=cut

# inplace merge of src with href of depth 2
# no merging at depth 1
sub _merge
{
    my ($src, $href) = @_;
    while (my ($k, $v) = each %$href) {
        $src->{$k} = {%{$src->{$k} || {}}, %$v};
    }
}

sub read_cfg
{
    my $self = shift;

    my $cfg = Config::Tiny->read_string($DEFAULT_CFG);

    if (-f $CFG_FILENAME ) {
        $self->info("TQU cfg file $CFG_FILENAME found");
        _merge($cfg, $cfg->read($CFG_FILENAME));
    } else {
        $self->verbose("No TQU cfg file $CFG_FILENAME found");
    }

    if ($main::TQU) {
        $self->info("main::TQU cfg string found");
        _merge($cfg, $cfg->read_string($main::TQU));
    } else {
        $self->verbose("No main::TQU cfg string found");
    };

    $self->{cfg} = $cfg;
}

=item test

Run all enabled tests, in order

=cut

sub test
{

    my ($self) = shift;

    $self->read_cfg();

    foreach my $test (@TESTS) {
        my $cfg = $self->{cfg}->{$test};
        if (! defined($cfg)) {
            $self->notok("No configuration section for test $test");
        } elsif (defined($cfg->{enable}) && $cfg->{enable} =~ m/^[0nNfF]/) {
            $self->ok("Test $test is disabled as requested");
        } else {
            $self->$test($cfg);
        };
    }
}

=item load

Run basic load test using C<use_ok> from C<Test::More>.

The module(s) can be configured or guessed.

Configuration parameters

=over

=item modules

Comma separated list op module names to try to load.

When specified, no guesses are made, only this list is used.

If C<:> is passed, the prefix is used.

All trailing C<:> are removed.

=item prefix

A prefix for all modules specified in the C<modules> option.

=back

=cut

# For unittesting, do not run tests
sub _get_modules
{
    my ($self, $cfg) = @_;

    my $prefix = $cfg->{prefix} || '';

    my @split = split(/\s*,\s*/, $cfg->{modules} || '');

    my @modules = map {my $txt = $_; $txt =~ s/:*$//; $txt} map {$prefix . ($_ eq ':' ? '' : $_)} @split;

    if (@modules) {
        $self->verbose("Configured modules to load: ", join(', ', @modules));
    } else {
        # Is this a component?
        if ($self->{component}) {
            push(@modules, "NCM::Component::$self->{component}");
        }

        if (@modules) {
            $self->verbose("Guessed modules to load: ", join(', ', @modules));
        } else {
            $self->verbose("No modules configured or guessed");
        };
    }

    return \@modules;
}

sub load
{

    my ($self, $cfg) = @_;

    my $modules = $self->_get_modules($cfg);

    if (@$modules) {
        foreach my $module (@$modules) {
            use_ok($module);
        }
    } else {
        $self->notok("No modules configured or guessed");
    }
}


=item doc

Documentation tests using C<Test::Quattor::Doc>.

Configuration options C<poddirs>, C<podfiles>, C<emptypoddirs>, C<panpaths> and
C<panout> are parsed as comma-seperated lists
and passed to C<< Test::Quattor::Doc->new >>.

If the C<nopodflag> attribute is true, and no C<emptypoddirs> are defined,
the C<Test::Quattor::Doc::DOC_TARGET_POD> is set as C<emptypoddirs>.

C<panpaths> value C<NOPAN> is special, as it disables the pan tests.

=cut

sub doc
{
    my ($self, $cfg) = @_;

    my %opts;
    foreach my $opt (qw(poddirs podfiles emptypoddirs panpaths panout)) {
        $opts{$opt} = [split(/\s*,\s*/, $cfg->{$opt})] if exists $cfg->{$opt};
    }

    if (!exists($opts{emptypoddirs}) && $self->{nopodflag}) {
        $opts{emptypoddirs} = [$Test::Quattor::Doc::DOC_TARGET_POD];
    }

    my $doc = Test::Quattor::Doc->new(%opts);
    if(($cfg->{panpaths} || '') eq 'NOPAN') {
        $self->verbose('disabling pan doc tests');
        $doc->{panpaths} = undef;
    }

    $doc->test();
}

=item tt

Run TT unittests using C<Test::Quattor::TextRender::Component>.
(This does not apply to C<metaconfig> tests).

Configuration options are passed to
C<< Test::Quattor::TextRender::Component->new >>.

The tests are only run if the basepath (default to C<src/main/resources>)
exists.

=cut

sub _guess_tt_component
{
    my ($self, $cfg) = @_;

    my $ttcomponent;

    if ($self->{component}) {
        $ttcomponent = $self->{component};
    }

    if (defined($self->{component})) {
        $self->verbose("Guessed the TT component");
    } else {
        $self->verbose("Unable to guess the TT component");
    }

    return $ttcomponent;
}

sub tt
{
    my ($self, $cfg) = @_;

    my %opts = %$cfg;
    delete $opts{enable};

    my $basepath = $opts{basepath} || Test::Quattor::TextRender::Component::_default_basepath();

    if (-d $basepath) {
        if (! $opts{component}) {
            $opts{component} = $self->_guess_tt_component();
        }

        if ($opts{component}) {
            $self->verbose("Run TT test with component $opts{component} and basepath $basepath");
            Test::Quattor::TextRender::Component->new(%opts)->test();
        } else {
            $self->notok("Cannot guess TT component with basepath $basepath");
        }
    } else {
        $self->verbose("Basepath $basepath does not exist, not running TT tests");
    }

}


=item critic

Run C<Test::Quattor::Critic>

Options

=over

=item codedirs

Comma-separated list of directories to look for code to test.
(Defaults to poddirs (from doc test) or C<target/lib/perl>).

=item exclude

A regexp to remove policies from list of fatal policies.

=back

=cut

sub critic
{
    my ($self, $cfg) = @_;

    my %opts;

    # default to poddirs if defined
    my $doccfg = $self->{cfg}->{doc};
    if (!exists($cfg->{codedirs}) && $doccfg && exists($doccfg->{poddirs})) {
        $self->verbose("Using poddirs as codedirs for critic test");
        $cfg->{codedirs} = $doccfg->{poddirs};
    };


    foreach my $opt (qw(codedirs)) {
        $opts{$opt} = [split(/\s*,\s*/, $cfg->{$opt})] if exists $cfg->{$opt};
    }
    $opts{exclude} = $cfg->{exclude} if $cfg->{exclude};

    Test::Quattor::Critic->new(%opts)->test();
}

=item tidy

Run C<Test::Quattor::Tidy>

Options

=over

=item codedirs

Comma-separated list of directories to look for code to test.
(Defaults to poddirs (from doc test) or C<target/lib/perl>).

=back

=cut

sub tidy
{
    my ($self, $cfg) = @_;

    my %opts;

    # default to poddirs if defined
    my $doccfg = $self->{cfg}->{doc};
    if (!exists($cfg->{codedirs}) && $doccfg && exists($doccfg->{poddirs})) {
        $self->verbose("Using poddirs as codedirs for critic test");
        $cfg->{codedirs} = $doccfg->{poddirs};
    };

    foreach my $opt (qw(codedirs)) {
        $opts{$opt} = [split(/\s*,\s*/, $cfg->{$opt})] if exists $cfg->{$opt};
    }

    Test::Quattor::Tidy->new(%opts)->test();
}

=pod

=back

=cut

1;
