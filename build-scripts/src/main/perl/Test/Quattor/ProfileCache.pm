# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;

package Test::Quattor::ProfileCache;

use base 'Exporter';

use CAF::FileWriter;
use Test::More;

use Cwd;
use Carp qw(carp croak);
use File::Path qw(mkpath);
use Cwd qw(getcwd);

use Test::Quattor::Object;
use Test::Quattor::Panc qw(panc set_panc_includepath get_panc_includepath);

use EDG::WP4::CCM::Configuration;
use EDG::WP4::CCM::CacheManager;
use EDG::WP4::CCM::Fetch;
use EDG::WP4::CCM::Element qw(escape unescape);
use EDG::WP4::CCM::CCfg;

use Readonly;

Readonly::Hash my %DEFAULT_PROFILE_CACHE_DIRS => {
    resources => "src/test/resources",
    profiles => "target/test/profiles",
    cache => "target/test/cache",
};

Readonly my $CCM_CONFIG_DEFAULT_TEMPLATE => <<"EOF";
debug 0
get_timeout 1
profile http://www.quattor.org
cache_root __CACHE_ROOT__
retrieve_wait 0
retrieve_retries 1
EOF

our @EXPORT = qw(get_config_for_profile prepare_profile_cache
                 set_profile_cache_options
                 prepare_profile_cache_panc_includedirs
                 set_json_typed get_json_typed
                );


# A Test::Quattor::Object instance, can be used as logger.
my $object = Test::Quattor::Object->new();


=pod

=head1 DESCRIPTION

Module to setup a profile cache

=cut

my (%configs, %profilecacheoptions);

=pod

=head2 set_profile_cache_options

Set additional options for prepare_profile_cache

Set specific values for the C<cache>, C<resources> and/or C<profiles> directory.
Will be used by C<get_profile_cache_dirs>

=over

=item cache

=item resources

=item profiles

=back

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

# get default ccm.cfg contents
sub get_ccm_config_default
{
    my $txt = "$CCM_CONFIG_DEFAULT_TEMPLATE";

    my $dirs = get_profile_cache_dirs();
    $txt =~ s/__CACHE_ROOT__/$dirs->{cache}/g;

    return $txt;
}

# convert e.g. absolute paths to usable name
sub profile_cache_name
{
    my ($profile) = @_;

    my $dirs = get_profile_cache_dirs();
    my $cachename = $profile;
    $cachename =~ s/\.pan$//;
    $cachename =~ s/^$dirs->{resources}\/+//;
    $cachename = escape($cachename);

    $object->debug("Converted profile $profile in cache name $cachename") if ($profile ne $cachename);

    return $cachename;

}

=pod

=head2 prepare_profile_cache_panc_includedirs

=cut

sub prepare_profile_cache_panc_includedirs
{
    my $dest = $object->make_target_pan_path();
    my $incdirs = get_panc_includepath();
    # Always add the current dir
    push(@$incdirs, '.') if (! (grep { $_ eq '.' } @$incdirs));
    push(@$incdirs, $dest) if (! (grep { $_ eq $dest } @$incdirs));

    # no failed test on missing template library core
    # to avoid issues with auto-detect, set the QUATTOR_TEST_TEMPLATE_LIBRARY_CORE
    # to non-existinig dir. (This is not supposed to cause any issues though)
    my $tlc = $object->get_template_library_core(0);
    push(@$incdirs, $tlc) if ($tlc && ! (grep { $_ eq $tlc } @$incdirs));

    set_panc_includepath(@$incdirs);
}

=pod

=head2 prepare_profile_cache

Prepares a cache for the profile given as an argument. This means
compiling the profile, fetching it and saving the binary cache
wherever the CCM configuration tells us.

Returns the configuration object for this profile.

The C<croak_on_error> argument is passed to the C<Test::Quattor::Panc::panc> method.
If this boolean is 0 (and not undef), C<prepare_profile_cache>
will return the C<panc> exitcode upon C<panc> failure.

=cut

sub prepare_profile_cache
{
    my ($profile, $croak_on_error) = @_;

    my $dirs = get_profile_cache_dirs();

    my $cachename = profile_cache_name($profile);

    my $cache = "$dirs->{cache}/$cachename";

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

    prepare_profile_cache_panc_includedirs();

    # Compile profiles
    my $ec = panc($profile, $dirs->{resources}, $dirs->{profiles}, $croak_on_error);
    # on failure, there's nothing to do any further.
    return $ec if($ec);

    # Support non-existing ccm.cfg
    # (also prevents having to ship same file over and over again)
    my $ccmconfig = "$dirs->{resources}/ccm.cfg";
    if( ! -f $ccmconfig) {
        # Make a new default one
        note("Creating default ccm.cfg in $dirs->{cache}");
        $ccmconfig = "$dirs->{cache}/ccm.cfg";
        if (! -f $ccmconfig) {
            my $fh = CAF::FileWriter->new($ccmconfig);
            print $fh get_ccm_config_default();
            $fh->close();
        }
    }

    # Setup CCM
    my $f = EDG::WP4::CCM::Fetch->new({
               FOREIGN => 0,
               CONFIG => $ccmconfig,
               CACHE_ROOT => $cache,
               PROFILE_URL => "file://$dirs->{profiles}/".unescape($cachename).".json",
               })
        or croak ("Couldn't create fetch object");
    $f->{CACHE_ROOT} = $cache;
    $f->fetchProfile() or croak "Unable to fetch profile $profile";

    my $cm =  EDG::WP4::CCM::CacheManager->new($cache);
    $configs{$cachename} = $cm->getUnlockedConfiguration();

    return $configs{$cachename};
}

=pod

=head2 C<get_config_for_profile>

Returns a configuration object for the profile given as an
argument. The profile should be one of the arguments given to this
module when loading it.

=cut

sub get_config_for_profile
{
    my ($profile) = @_;

    return $configs{profile_cache_name($profile)};
}

=pod

=head2 C<set_json_typed>

Set the json_typed config attribute to C<value>.
If value is undefined, C<json_typed> is set to true.

Returns the value set.

=cut

sub set_json_typed
{
    my $value = shift;
    $value = 1 if(! defined($value));
    return EDG::WP4::CCM::CCfg::_setCfgValue('json_typed', $value ? 1 : 0);
}

=pod

=head2 C<get_json_typed>

Return the C<json_typed> value.

=cut

sub get_json_typed
{
    return EDG::WP4::CCM::CCfg::getCfgValue('json_typed')
};

1;
