use strict;
use warnings;

package Test::Quattor::Panc;

use base 'Exporter';

use Test::More;
use Readonly;

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

=cut

sub panc
{

    my ($profile, $resourcesdir, $outputdir) = @_;

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

    my $pancmsg = "Pan compiler called with: ".join(" ", @panccmd)." from directory ".getcwd();
    if(system(@panccmd)) {
        croak("Unable to compile profile $profile. Minimal panc version is $PANC_MINIMAL. $pancmsg");
    } else {
        note($pancmsg);
    }
    chdir($currentdir);
};


1;
