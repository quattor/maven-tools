# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

package Test::Quattor::Doc;

use strict;
use warnings;

use base qw(Test::Quattor::Object Exporter);
use Test::More;
use Test::Pod;
use Pod::Simple 3.28;
use File::Path qw(mkpath);
use Test::Quattor::Panc qw(panc_annotations);

use Readonly;

Readonly our $DOC_TARGET_PERL => "target/lib/perl";
Readonly our $DOC_TARGET_POD => "target/doc/pod";
Readonly our $DOC_TARGET_PAN => "target/pan";
Readonly our $DOC_TARGET_PANOUT => "target/panannotations";
Readonly::Array our @DOC_TEST_PATHS => ($DOC_TARGET_PERL, $DOC_TARGET_POD);

our @EXPORT = qw($DOC_TARGET_PERL $DOC_TARGET_POD @DOC_TEST_PATHS
                 $DOC_TARGET_PAN $DOC_TARGET_PANOUT);

=pod

=head1 NAME

Test::Quattor::Doc - Class for unittesting documentation.

=head1 DESCRIPTION

This is a class to trigger documentation testing.
Should be used mainly as follows:

    use Test::Quattor::Doc;
    Test::Quattor::Doc->new()->test();

=head2 Public methods

=over

=item new

Returns a new object, accepts the following options

=over

=item poddirs

Array reference of directories to test for podfiles.
Default dirs are the relative paths C<target/lib/perl>
and C<target/doc/pod> (use the exported C<@DOC_TEST_PATHS>
list of defaults or resp. C<$DOC_TARGET_PERL> and <$DOC_TARGET_POD>)

=item podfiles

Array reference of podfiles to test (default empty)

=item emptypoddirs

Array reference of poddirs that must be empty (or non-existing).
If a directory is in both C<poddirs> and C<emptypoddirs>,
if is considered an empty poddir.

=item panpaths

Array reference of paths that hold pan files to check for annotations.
Default is C<target/pan> (use the exported $DOC_TARGET_PAN).

=item panout

Output path for pan annotations. Default
target/panannotations (use exported $DOC_TARGET_PANOUT).

=back

=cut

sub _initialize
{
    my ($self) = @_;

    $self->{poddirs} = \@DOC_TEST_PATHS if (! defined($self->{poddirs}));
    $self->{podfiles} = [] if (! defined($self->{podfiles}));
    $self->{emptypoddirs} = [] if (! defined($self->{emptypoddirs}));

    $self->{panpaths} = [$DOC_TARGET_PAN] if (! defined($self->{panpaths}));
    $self->{panout} = $DOC_TARGET_PANOUT if (! defined($self->{panout}));
}


=pod

=item pod_files

Test all files from C<podfiles> and C<poddirs>.
Based on C<all_pod_files_ok> from C<Test::Pod>.

Returns array refs of all ok and not ok files.

=cut

sub pod_files
{
    my $self = shift;

    my @files = @{$self->{podfiles}};
    foreach my $dir (@{$self->{poddirs}}) {
        next if (grep {$_ eq $dir} @{$self->{emptypoddirs}});
        $self->notok("poddir $dir is not a directory") if ! -d $dir;
        my @fs = all_pod_files($dir);
        # Do not allow empty pod dirs,
        # remove them from the poddirs if they are not relevant
        ok(@fs, "Directory $dir has files");
        push(@files, @fs);
    };

    foreach my $dir (@{$self->{emptypoddirs}}) {
        if (! -d $dir) {
            $self->notok("emptypoddir $dir is not a directory")
        } else {
            my @fs = all_pod_files($dir);
            ok(! @fs, "emptypoddir $dir has no files");
        };
    };

    my (@ok, @not_ok);
    foreach my $file (@files) {
        ok(-f $file, "pod file $file is a file");

        # each pod_file_ok is also a test.
        if(pod_file_ok($file)) {
            push(@ok, $file);
        } else {
            push(@not_ok, $file);
        }
    }

    return \@ok, \@not_ok;
}

=pod

=item pan_annotations

Generate annotations, return arrayref with templates that
have valid annotations and one for templates with invalid annotations.

TODO: Does not require annotations at all nor validates
minimal contents.

=cut

# internal method that does actual work
# factored out so it can be run multiple times
# to work around bug in panc-annotations
# see https://github.com/quattor/maven-tools/issues/143
sub _panc_annotations
{
    my ($self, $dir, $templates, $msg) = @_;

    $msg = '' if ! defined $msg;
    my (@ok, @not_ok);
    my $res = panc_annotations($dir, $self->{panout}, $templates);
    my ($ec, $output) = @$res;

    if ($ec) {
        $self->notok("${msg}panc-annotations ended with ec $ec");
        push(@not_ok, @$templates);
    } else {
        my $missing_annotation;
        foreach my $tmpl (@$templates) {
            my $anno = "$self->{panout}/$tmpl.annotation.xml";
            if (-f $anno) {
                push(@ok, $tmpl);
            } else {
                $self->verbose("${msg}Did not find annotation xml $anno for template $tmpl");
                $missing_annotation = 1;
                push(@not_ok, $tmpl);
            }
        }
        if (!$missing_annotation) {
            $self->verbose("${msg}Templates with missing xml with command stdout/stderr $output");
        };
    }
    return \@ok, \@not_ok;
}

sub pan_annotations
{
    my $self = shift;

    mkpath($self->{panout}) if ! -d $self->{panout};
    ok(-d $self->{panout}, "annotations output dir $self->{panout} exists");

    my (@ok, @not_ok);
    foreach my $dir (@{$self->{panpaths}}) {
        my ($okpan, $notok_pan) = $self->gather_pan($dir, $dir, "");
        is(scalar @$notok_pan, 0, "No invalid pan files found in $dir (no namespace checked for annotations)");
        my @templates = sort keys %$okpan;
        ok(@templates, "Found valid templates in $dir");

        my ($tmpok, $tmpnot_ok) = $self->_panc_annotations($dir, \@templates, 'run 1: ');
        if (@$tmpok) {
            push(@ok, @$tmpok);
            if (@$tmpnot_ok) {
                my ($tmpok2, $tmpnot_ok2) = $self->_panc_annotations($dir, $tmpnot_ok, 'run 2: ');
                push(@not_ok, @$tmpnot_ok2);
                push(@ok, @$tmpok2);
            };
        } else {
            # main failure; do not bother with retry
            push(@not_ok, @$tmpnot_ok);
        }
    }

    return \@ok, \@not_ok;
}

=pod

=item test

Run all tests:
    pod_files
    pan_annotations

=cut

sub test
{
    my ($self) = @_;

    my ($ok, $not_ok) = $self->pod_files();
    is(scalar @$not_ok, 0, "No faulty pod files: ");

    if (defined($self->{panpaths})) {
        ($ok, $not_ok) = $self->pan_annotations();
        is(scalar @$not_ok, 0, "No faulty pan annotation: ".join(",", @$not_ok));
    }
}

=pod

=back

=cut

1;
