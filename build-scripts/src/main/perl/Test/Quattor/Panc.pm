# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;

package Test::Quattor::Panc;

use base 'Exporter';

use Test::More;
use Readonly;

use CAF::Process;
use Test::MockModule;

use Cwd;
use Carp qw(carp croak);
use File::Path qw(mkpath);
use Cwd qw(getcwd);

our @EXPORT = qw(panc
                 set_panc_options reset_panc_options get_panc_options
                 set_panc_includepath get_panc_includepath);

Readonly my $PANC_MINIMAL => '10.2';

=pod

=head1 DESCRIPTION

Module to compile profiles using panc

=cut

my (%pancoptions);

=pod

=head2 set_panc_options

Set additional panc commandline options.
Use the long option name, the preceding '--' is added.
If no value is expected (e.g. '--debug') pass 'undef' as value.

=cut

sub set_panc_options
{
    my (%options) = @_;
    while (my ($option, $value) = each %options) {
        $pancoptions{$option} = $value;
    }
}


=pod

=head2 reset_panc_options

Reset the panc commandline options.

=cut

sub reset_panc_options
{
    %pancoptions = ();
}

=pod

head2 get_panc_options

Returns the hash reference to the additional pancoptions.

=cut

sub get_panc_options
{
    return \%pancoptions;
}

=pod

=head2 set_panc_includepath

Set the inlcudedirs option to the directories passed.
If undef is passed, remove the 'includepath' option.

=cut

sub set_panc_includepath
{
    my (@dirs) = @_;

    if (@dirs) {
        $pancoptions{"include-path"} = join(':', @dirs);
    } else {
        delete $pancoptions{"include-path"};
    }

}

=pod

=head2 get_panc_includepath

Return an array reference with the 'includepath' directories.

=cut

sub get_panc_includepath
{
    if (exists($pancoptions{"include-path"})) {
        my @dirs = split(':', $pancoptions{"include-path"});
        return \@dirs;
    } else {
        return [];
    }
}

=pod

=head2 Compile pan object template into JSON profile

Compile the pan C<profile> (file 'C<profile>.pan' in C<resourcesdir>)
and create the profile in C<outputdir>.

If C<croak_on_error> is true (or undef), the method croaks on compilation failure.
If false, it will return the exitcode.

=cut

sub panc
{

    my ($profile, $resourcesdir, $outputdir, $croak_on_error) = @_;

    $croak_on_error = 1 if (! defined($croak_on_error));

    if( ! -d $outputdir) {
        mkpath($outputdir)
            or croak("Couldn't create output directory $outputdir");
    }

    my $currentdir = getcwd();
    chdir($resourcesdir) or croak("Couldn't enter resources directory $resourcesdir");

    my @panccmd = qw(panc --formats json --output-dir);
    push(@panccmd, $outputdir);
    while (my ($option,$value) = each %pancoptions) {
        push(@panccmd, "--$option");
        # support options like --debug with no value
        push(@panccmd, $value) if (defined($value));
    }
    $profile .= ".pan" if ($profile !~ m/\.pan$/ );
    push(@panccmd, $profile);

    my $output;
    # Test::MockModule keeps the currently mocked modules in a local hash,
    # and will return a previously existing one.
    my $mock = Test::MockModule->new('CAF::Process');

    my $proc = CAF::Process->new(\@panccmd, stdout => \$output, stderr => 'stdout');

    # avoid possible mocking, call original method if needed
    if($mock->is_mocked("execute")) {
        my $execute = $mock->original("execute");
        $execute->($proc);
    } else {
        $proc->execute();
    };
    chdir($currentdir);

    my $pancmsg = "Pan compiler called with: $proc from directory $resourcesdir";
    if($?) {
        my $msg = "Unable to compile profile $profile. Minimal panc version is $PANC_MINIMAL. ";
        $msg .= "$pancmsg with output\n$output";
        if($croak_on_error) {
            croak($msg);
        } else {
            diag($msg);
        }
    } else {
        note($pancmsg);
    }

    return $?;
};


1;
