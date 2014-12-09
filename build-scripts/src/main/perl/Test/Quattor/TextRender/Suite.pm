# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}

use strict;
use warnings;

package Test::Quattor::TextRender::Suite;

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

=item includepath

Includepath to use for CAF::TextRender.

=back

=cut

# TODO rename all references here and in actual directories to resources for uniform naming

sub _initialize
{
    my ($self) = @_;

    $self->{includepath} = abs_path($self->{includepath});
    ok(-d $self->{includepath}, "includepath $self->{includepath} exists");

    $self->{testspath} = abs_path($self->{testspath});
    ok(-d $self->{testspath}, "testspath $self->{testspath} exists");

    if ($self->{profilespath}) {
        if ($self->{profilespath} !~ m/^\//) {
            $self->verbose("Relative profilespath $self->{profilespath} found");
            $self->{profilespath} = "$self->{testspath}/$self->{profilespath}";
        }
    } else {
        $self->{profilespath} = "$self->{testspath}/profiles";
    }
    $self->{profilespath} = abs_path($self->{profilespath});
    ok(-d $self->{profilespath}, "profilespath $self->{profilespath} exists");

    if ($self->{regexpspath}) {
        if ($self->{regexpspath} !~ m/^\//) {
            $self->verbose("Relative regexpspath $self->{regexpspath} found");
            $self->{regexpspath} = "$self->{testspath}/$self->{regexpspath}";
        }
    } else {
        $self->{regexpspath} = "$self->{testspath}/regexps";
    }
    $self->{regexpspath} = abs_path($self->{regexpspath});
    ok(-d $self->{regexpspath}, "Init regexpspath $self->{regexpspath} exists");

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

    opendir(DIR, $self->{regexpspath});

    foreach my $name (grep {!m/^\./} sort readdir(DIR)) {
        my $abs = "$self->{regexpspath}/$name";
        if (-f $abs) {
            $self->verbose("Found regexps file $name (abs $abs)");
            $regexps{$name} = [$name];
        } elsif (-d $abs) {
            opendir(my $dh, $abs);

            # only files
            my @files = map {"$name/$_"} grep {!m/^\./ && -T "$abs/$_"} sort readdir($dh);
            closedir $dh;
            $self->verbose(
                "Found regexps directory $name (abs $abs) with files " . join(", ", @files));
            $regexps{$name} = \@files;
        } else {
            $self->notok("Invalid regexp abs $abs found");
        }
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
        $objs{$name} = $pan if ($value->{type} eq 'object');
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

    # Compile, setup CCM cache and get the configuration instance
    my $cfg = prepare_profile_cache($profile);

    foreach my $regexp (@$regexps) {
        my $regexptest = Test::Quattor::TextRender::RegexpTest->new(
            regexp      => "$self->{regexpspath}/$regexp",
            config      => $cfg,
            includepath => $self->{includepath},
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
    push(@$incdirs, $self->{profilespath});
    set_panc_includepath(@$incdirs);

    set_profile_cache_options(resources => $self->{profilespath});

    foreach my $name (keys %$regexps) {
        $self->regexptest($name, "$self->{profilespath}/$profiles->{$name}", $regexps->{$name});
    }

}

1;
