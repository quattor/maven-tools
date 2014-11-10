use strict;
use warnings;

package Test::Quattor::ProfileCache;

use base 'Exporter';

use CAF::FileWriter;
use Test::More;

use Cwd;
use Carp qw(carp croak);
use File::Path qw(mkpath);

use EDG::WP4::CCM::Configuration;
use EDG::WP4::CCM::CacheManager;
use EDG::WP4::CCM::Fetch;

use Readonly;

Readonly::Hash my %DEFAULT_PROFILE_CACHE_DIRS => {
    resources => "src/test/resources",
    profiles => "target/test/profiles",
    cache => "target/test/cache",
};

our @EXPORT = qw(get_config_for_profile prepare_profile_cache
                 set_profile_cache_options
                 set_panc_options reset_panc_options);

=pod

=head1 DESCRIPTION

Module to setup a profile cache 

=cut

my (%configs, %pancoptions, %profilecacheoptions);

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

=pod

=head2 set_profile_cache_options

Set additional options for prepare_profile_cache

=item cache, resources and/or profiles

Set specific values for the C<cache>, C<resources> and/or C<profiles> directory.
Will be used by C<get_profile_cache_dirs>

=cut

sub set_profile_cache_options
{
    my (%options) = @_;
    while (my ($option, $value) = each %options) {
        $profilecacheoptions{$option} = $value;
    }
}


=pod

=head2 get_profile_cache_dirs

Return hashreference to the directories used to setup
the profile cache: 'cache', 'resources' and 'profiles'.

The values are generated from the defaults or C<profilecacheoptions>
(to be set via C<set_profile_cache_options>).

Relative paths are assumed to be relative wrt current directory; 
absolute paths are used for the returned values.

=cut

sub get_profile_cache_dirs
{
    my $currentdir = getcwd();

    my %dirs;

    my @types = qw(cache profiles resources);
    foreach my $type (@types) {
        my $dir = $DEFAULT_PROFILE_CACHE_DIRS{$type};
        $dir = $profilecacheoptions{$type} if (exists($profilecacheoptions{$type}));
        $dir = "$currentdir/$dir" if ($dir !~ m/^\//);
        $dirs{$type} = $dir;
    }
    
    return \%dirs;
}

=pod

=head2 prepare_profile_cache

Prepares a cache for the profile given as an argument. This means
compiling the profile, fetching it and saving the binary cache
wherever the CCM configuration tells us.

Returns the configuration object for this profile.

=cut

sub prepare_profile_cache
{
    my ($profile) = @_;

    my $dirs = get_profile_cache_dirs();

    my $cache = "$dirs->{cache}/$profile";

    mkpath($cache);

    my $fh = CAF::FileWriter->new("$cache/global.lock");
    print $fh "no\n";
    $fh->close();
    $fh = CAF::FileWriter->new("$cache/current.cid");
    print $fh "1\n";
    $fh->close();
    $fh = CAF::FileWriter->new("$cache/latest.cid");
    print $fh "1\n";
    $fh->close();

    # Compile profiles
    panc($profile, $dirs->{resources}, $dirs->{profiles});

    # Setup CCM
    my $f = EDG::WP4::CCM::Fetch->new({
               FOREIGN => 0,
               CONFIG => "$dirs->{resources}/ccm.cfg",
               CACHE_ROOT => $cache,
               PROFILE_URL => "file://$dirs->{profiles}/$profile.json",
               })
        or croak ("Couldn't create fetch object");
    $f->{CACHE_ROOT} = $cache;
    $f->fetchProfile() or croak "Unable to fetch profile $profile";

    my $cm =  EDG::WP4::CCM::CacheManager->new($cache);
    $configs{$profile} = $cm->getUnlockedConfiguration();
    
    return $configs{$profile};
}

=pod

=item C<get_config_for_profile>

Returns a configuration object for the profile given as an
argument. The profile should be one of the arguments given to this
module when loading it.

=cut

sub get_config_for_profile
{
    my ($profile) = @_;

    return $configs{$profile};
}

1;
