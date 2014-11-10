use strict;
use warnings;

package Test::Quattor::Panc;

use base 'Exporter';

use Test::More;

use Cwd;
use Carp qw(carp croak);
use File::Path qw(mkpath);

our @EXPORT = qw(panc set_panc_options reset_panc_options);

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


# get_panc_options returns hash reference to the additional pancoptions
# test function only?
sub get_panc_options
{
    return \%pancoptions;
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
    push(@panccmd, "$profile.pan");
    
    note("Pan compiler called with: ".join(" ", @panccmd));
    system(@panccmd) == 0
        or croak("Unable to compile profile $profile");

    chdir($currentdir);
};


1;
