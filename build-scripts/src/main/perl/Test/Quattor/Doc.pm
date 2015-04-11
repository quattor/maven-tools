# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;

package Test::Quattor::Doc;

use base qw(Test::Quattor::Object Exporter);
use Test::More;
use Test::Pod;

use Readonly;

Readonly our $DOC_TARGET_PERL => "target/lib/perl";
Readonly our $DOC_TARGET_POD => "target/doc/pod";
Readonly::Array our @DOC_TEST_PATHS => ($DOC_TARGET_PERL, $DOC_TARGET_POD);

our @EXPORT = qw($DOC_TARGET_PERL $DOC_TARGET_POD @DOC_TEST_PATHS);

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

=back

=cut

sub _initialize
{
    my ($self) = @_;

    $self->{poddirs} = \@DOC_TEST_PATHS if (! defined($self->{poddirs}));
    $self->{podfiles} = [] if (! defined($self->{podfiles}));

}


=pod

=item all_pod_files_ok

Test all files from C<podfiles> and C<poddirs>.
Based on C<all_pod_files_ok> from C<Test::Pod>.

Returns array refs of all ok and not ok files.

=cut

sub all_pod_files_ok
{
    my $self = shift;

    my @files = @{$self->{podfiles}};
    foreach my $dir (@{$self->{poddirs}}) {
        $self->notok("poddir $dir is not a directory") if ! -d $dir;
        my @fs = all_pod_files($dir);
        # Do not allow empty pod dirs, 
        # remove them from the poddirs if they are not relevant
        ok(@fs, "Directory $dir has files");
        push(@files, @fs);
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

=item test

Run all tests: 
    all_pod_files_ok
    
=cut

sub test
{
    my ($self) = @_;
    
    my ($ok, $not_ok) = $self->all_pod_files_ok();
    is(scalar @$not_ok, 0, "No faulty pod files");
    
}

=pod

=back

=cut

1;

