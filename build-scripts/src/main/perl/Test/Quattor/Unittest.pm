# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;

package Test::Quattor::Unittest;

use parent qw(Test::Quattor::Object);
use Config::Tiny;
use Readonly;
use Test::More;

my $do_test = 1;
# This is the very last thing to do
# Defined here to always run as last, even after the END from e.g. NoWarnings
END {
    done_testing() if $do_test;
}

use Test::Quattor::Doc;

# When changing, also change the pod in read_cfg
Readonly our $CFG_FILENAME => 'tqu.cfg';
Readonly our $DEFAULT_CFG => <<'EOF';
[load]
enable = 1

[doc]
enable = 1

EOF

Readonly::Array our @TESTS => qw(load doc);

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

=item import

On import, run the tests.

Pass C<notest> to disable automatic testing
(only useful when testing this code).

=cut

sub import
{
    my $class = shift;

    $do_test = ! grep {m/notest/} @_;
    $class->new()->test() if $do_test;
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
set to true by default. For all other options, read the respective method
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

    my @modules = map {s/:*$//;$_} map {$prefix . ($_ eq ':' ? '' : $_)} @split;

    if (@modules) {
        $self->verbose("Configured modules to load: ", join(', ', @modules));
    } else {
        # Is this a component?


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

Configuration options C<poddirs>, C<podfiles>, C<panpaths> and
C<panout> are prased as comma-sperated lists
and passed to C<Test::Quattor::Doc->new>.

C<panpaths> value C<NOPAN> is special, as it disables the pan tests.

=cut

sub doc
{
    my ($self, $cfg) = @_;

    my %opts;
    foreach my $opt (qw(poddirs podfiles panpaths panout)) {
        $opts{$opt} = [split(/\s*,\s*/, $cfg->{$opt})] if exists $cfg->{$opt};
    }

    my $doc = Test::Quattor::Doc->new(%opts);
    if(($cfg->{panpaths} || '') eq 'NOPAN') {
        $self->verbose('disabling pan doc tests');
        $doc->{panpaths} = undef;
    }

    $doc->test();
}

=pod

=back

=cut

1;
