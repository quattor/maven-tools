# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

package Test::Quattor::TextRender::Suite;

use strict;
use warnings;

use Test::More;
use Cwd qw(abs_path);

use File::Basename;
use File::Find;

use Test::Quattor::ProfileCache qw(prepare_profile_cache set_profile_cache_options);
use Test::Quattor::Panc qw(set_panc_includepath get_panc_includepath);

use Test::Quattor::TextRender::RegexpTest;

use base qw(Test::Quattor::Object);

=pod

=head1 NAME

Test::Quattor::TextRender::Suite - Class for a template test suite.

=head1 DESCRIPTION

A TextRender test suite corresponds to one or more
regexptests that are tested against the profile genereated
from one corresponding object template.

A test suite can be a combination of file (implying one regexptest, and that
file being the regexptest) and/or a directory
(one or more regexptests; each file in the directory is one
regexptest; no subdirectory structure allowed);
with the file or directory name
identical to the corresponding object template.

The names cannot start with a '.'.

=head1 new

Support options

=over

=item testspath

Basepath for the suite tests.

=item regexps

Path to the suite regexptests  (C<testspath>/regexps is default when not specified).

=item profiles

Path to the suite object templates (C<testspath>/profiles is default when not specified).

=item ttincludepath

Includepath to use for CAF::TextRender.

=item ttrelpath

relpath to use for CAF::TextRender.

=item filter

A compiled regular expression that is used to filter the found regexptest files
(matching relative filenames are kept; non-matcing ones are removed).

One can also set the C<QUATTOR_TEST_SUITE_FILTER> enviroment variable, which will be
used as regular expression pattern for the filter.

=back

=cut

# TODO rename all references here and in actual directories to resources for uniform naming

sub _initialize
{
    my ($self) = @_;

    # TT includepath
    $self->{ttincludepath} = abs_path($self->{ttincludepath});
    if (defined($self->{ttincludepath})) {
        ok(-d $self->{ttincludepath}, "TT includepath $self->{ttincludepath} exists");
    } else {
        $self->notok("ttincludepath not defined");
    }

    # TT relpath
    ok($self->{ttrelpath}, "TT relpath defined ".($self->{ttrelpath} || '<undef>'));

    # testspath
    $self->{testspath} = abs_path($self->{testspath});
    if (defined($self->{testspath})) {
        ok(-d $self->{testspath}, "testspath $self->{testspath} exists");
    } else {
        $self->notok("testspath not defined");
    }

    # profilespath
    if ($self->{profilespath}) {
        if ($self->{profilespath} !~ m/^\//) {
            $self->verbose("Relative profilespath $self->{profilespath} found");
            $self->{profilespath} = "$self->{testspath}/$self->{profilespath}";
        }
    } else {
        $self->{profilespath} = "$self->{testspath}/profiles";
    }
    $self->{profilespath} = abs_path($self->{profilespath});
    if (defined($self->{profilespath})) {
        ok(-d $self->{profilespath}, "profilespath $self->{profilespath} exists");
    } else {
        $self->notok("profilespath not defined");
    }

    # regexpspath
    if ($self->{regexpspath}) {
        if ($self->{regexpspath} !~ m/^\//) {
            $self->verbose("Relative regexpspath $self->{regexpspath} found");
            $self->{regexpspath} = "$self->{testspath}/$self->{regexpspath}";
        }
    } else {
        $self->{regexpspath} = "$self->{testspath}/regexps";
    }
    $self->{regexpspath} = abs_path($self->{regexpspath});
    if (defined($self->{regexpspath})) {
        ok(-d $self->{regexpspath}, "regexpspath $self->{regexpspath} exists");
    } else {
        $self->notok("regexpspath not defined");
    }

    # Filter
    my $filter = $ENV{QUATTOR_TEST_SUITE_FILTER};
    if ($filter) {
        $self->{filter} = qr{$filter};
        $self->info(
            "Filter $self->{filter} set via environment variable QUATTOR_TEST_SUITE_FILTER");
    }

    if ($self->{filter}) {
        $self->verbose("Filter $self->{filter} defined");
    }

}

=pod

=head2 gather_regexp

Find all regexptests. Files/directories that start with a '.' are ignored.

Returns hash ref with name as key and array ref of the regexptests paths.

=cut

sub gather_regexp
{
    my ($self) = @_;

    my %regexps;

    if (!-d $self->{regexpspath}) {
        $self->notok("regexpspath $self->{regexpspath} is not a directory");
        return \%regexps;
    }

    opendir(DIR, $self->{regexpspath});

    foreach my $name (grep {!m/^\./} sort readdir(DIR)) {
        my $abs = "$self->{regexpspath}/$name";
        my @files;
        if (-f $abs) {
            $self->verbose("Found regexps file $name (abs $abs)");
            push(@files, $name);
        } elsif (-d $abs) {
            opendir(my $dh, $abs);

            # only files
            @files = map {"$name/$_"} grep {!m/^\./ && -T "$abs/$_"} sort readdir($dh);
            closedir $dh;
            $self->verbose(
                "Found regexps directory $name (abs $abs) with files " . join(", ", @files));
        } else {
            $self->notok("Invalid regexp abs $abs found");
        }

        if ($self->{filter}) {
            @files = grep {/$self->{filter}/} @files;
            $self->verbose("After filter $self->{filter} files " . join(", ", @files));
        }

        $regexps{$name} = \@files if @files;
    }

    closedir(DIR);

    return \%regexps;
}

=pod

=head2 gather_profile

Create a hash reference of all object templates in the 'profilespath'
with name key and filepath as value.

=cut

sub gather_profile
{
    my ($self) = @_;

    # empty namespace
    my ($pans, $ipans) = $self->gather_pan($self->{profilespath}, $self->{profilespath}, '');

    is(scalar @$ipans, 0, 'No invalid pan templates');

    my %objs;
    while (my ($pan, $value) = each %$pans) {
        my $name = basename($pan);
        $name =~ s/\.pan$//;
        if ($value->{type} eq 'object') {
            if ((! $self->{filter}) || $name =~ m/$self->{filter}/) {
                $objs{$name} = $pan;
            }
        }
    }

    return \%objs;
}

=pod

=head2 one_test

Run all regexptest C<$regexps> for a single test profile C<profile> with name C<name>.

=cut

sub regexptest
{
    my ($self, $name, $profile, $regexps) = @_;

    $self->verbose("regexptest name $name profile $profile");

    # Compile, setup CCM cache and get the configuration instance
    my $cfg = prepare_profile_cache($profile);

    foreach my $regexp (@$regexps) {
        my $regexptest = Test::Quattor::TextRender::RegexpTest->new(
            regexp      => "$self->{regexpspath}/$regexp",
            config      => $cfg,
            ttrelpath     => $self->{ttrelpath},
            ttincludepath => $self->{ttincludepath},
        )->test();
    }

}

=pod

=head2 test

Run all tests to validate the suite.

=cut

sub test
{

    my ($self) = @_;

    my $regexps = $self->gather_regexp();
    ok($regexps, "Found regexps");

    my $profiles = $self->gather_profile();
    ok($profiles, "Found profiles");

    is_deeply([sort keys %$regexps], [sort keys %$profiles], "All regexps have matching profile");

    my $incdirs = get_panc_includepath();
    push(@$incdirs, $self->{profilespath}) if (! (grep { $_ eq $self->{profilespath}} @$incdirs));
    set_panc_includepath(@$incdirs);

    set_profile_cache_options(resources => $self->{profilespath});

    foreach my $name (sort keys %$regexps) {
        $self->regexptest($name, "$self->{profilespath}/$profiles->{$name}", $regexps->{$name});
    }

}

1;
