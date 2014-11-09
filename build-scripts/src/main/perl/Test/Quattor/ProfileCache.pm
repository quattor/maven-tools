use strict;
use warnings;

package Test::Quattor::ProfileCache;

use base 'Exporter';

use CAF::FileWriter;

use Cwd;
use Carp qw(carp croak);
use File::Path qw(mkpath);

use EDG::WP4::CCM::Configuration;
use EDG::WP4::CCM::CacheManager;
use EDG::WP4::CCM::Fetch;

our @EXPORT = qw(get_config_for_profile prepare_profile_cache);

=pod

=head1 DESCRIPTION

Module to setup a profile cache 

=cut

my %configs;

=pod

=head2 prepare_profile_cache

Prepares a cache for the profile given as an argument. This means
compiling the profile, fetching it and saving the binary cache
wherever the CCM configuration tells us.

=cut

sub prepare_profile_cache
{
    my ($profile) = @_;

    my $cache = "target/test/cache/$profile";
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

    # Make output dir
    mkpath("target/test/profiles");

    my $d = getcwd();

    chdir("src/test/resources") or croak("Couldn't enter resources directory");

    system(qw(panc --formats json --output-dir ../../../target/test/profiles), "$profile.pan") == 0
        or croak("Unable to compile profile $profile");

    chdir($d);
    my $f = EDG::WP4::CCM::Fetch->new({
               FOREIGN => 0,
               CONFIG => 'src/test/resources/ccm.cfg',
               CACHE_ROOT => $cache,
               PROFILE_URL => "file://$d/target/test/profiles/$profile.json",
               })
        or croak ("Couldn't create fetch object");
    $f->{CACHE_ROOT} = $cache;
    $f->fetchProfile() or croak "Unable to fetch profile $profile";

    my $cm =  EDG::WP4::CCM::CacheManager->new($cache);
    $configs{$profile} = $cm->getUnlockedConfiguration();
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
