use strict;
use warnings;

# Compatibility with pre ccm-17.2
my $config_class;
BEGIN {
    $config_class = "EDG::WP4::CCM::CacheManager::Configuration";
    local $@;
    eval "use $config_class";
    if ($@) {
        $config_class =~ s/CacheManager:://;
    }
}

use Test::More;

use Cwd;

use EDG::WP4::CCM::Path qw(escape);

use Test::Quattor::ProfileCache qw(prepare_profile_cache
    get_config_for_profile set_profile_cache_options
    get_profile_cache_dirs set_json_typed get_json_typed
    %DEFAULT_PROFILE_CACHE_DIRS);
use Test::Quattor::Object qw($TARGET_PAN_RELPATH);
use Test::Quattor::Panc qw(get_panc_includepath);
use Cwd qw(getcwd);
use File::Temp qw(tempdir);
use File::Path qw(mkpath);

is_deeply(\%DEFAULT_PROFILE_CACHE_DIRS,
          {
              resources => "src/test/resources",
              profiles => "target/test/profiles",
              cache => "target/test/cache",
          }, "Expected DEFAULT_PROFILE_CACHE_DIRS");

# Can't have NoAction here, since no CAF mocking happens
# and otherwise nothing would be written

my $json_typed = get_json_typed();

ok(set_json_typed(), "Set json_typed to true");
ok(get_json_typed(), "json_typed set to true");
ok(! set_json_typed(0), "Set json_typed to false");
ok(! get_json_typed(), "json_typed set to false");
ok(set_json_typed(1), "Set json_typed to true");
ok(get_json_typed(), "json_typed set to true");
# restore
set_json_typed($json_typed);

my $target = getcwd()."/target";
mkpath($target) if ! -d $target;
my $tmp_tlc_dir = tempdir(DIR => $target);

$ENV{QUATTOR_TEST_TEMPLATE_LIBRARY_CORE} = $tmp_tlc_dir;

# Test default ccm.cfg
my $ccm_default = <<"EOF";
debug 0
get_timeout 1
profile http://www.quattor.org
cache_root $target/test/cache
retrieve_wait 0
retrieve_retries 1
tabcompletion 0
EOF

my $ccmcfg = Test::Quattor::ProfileCache::get_ccm_config_default();
is($ccmcfg, $ccm_default,
   "get_ccm_config_default returned expected config with default value for cache_root");


my $cfg = prepare_profile_cache('profilecache');

isa_ok($cfg, $config_class, "get_config_for_profile returns a $config_class instance");

is_deeply($cfg->getElement("/")->getTree(),
            {test => "data"},
            "getTree of root element returns correct hashref");

# there should be a target/pan dir and should be in includepath
is($TARGET_PAN_RELPATH, 'target/pan', 'TARGET_PAN_RELPATH is exported');
my $dest = getcwd() . "/$TARGET_PAN_RELPATH";
ok(-d $dest, "$TARGET_PAN_RELPATH directory exists");
my $includedir = get_panc_includepath();
ok((grep {$_ eq $dest} @$includedir), "the $TARGET_PAN_RELPATH directory is in panc includepath");
ok((grep {$_ eq '.'} @$includedir), "the '.' directory is in panc includepath");
ok((grep {$_ eq $tmp_tlc_dir} @$includedir), "the QUATTOR_TEST_TEMPLATE_LIBRARY_CORE directory is in panc includepath");

# test the controlled failure of broken templates
# this also passes if the file is simply missing
my $profname = 'profilecache_broken';
my $absprof = getcwd()."/src/test/resources/$profname.pan";
ok(-f $absprof, "Broken template $profname exists: $absprof");
my $ec = prepare_profile_cache($profname, 0);
ok($ec, "Non-zero exitcode for brokenprofile with croak_on_error set to 0");


my $cfg2 = get_config_for_profile('profilecache');
is_deeply($cfg, $cfg2,
          "get_config_for_profile fecthes same configuration object as returned by prepare_profile_cache");

# verify defaults; they shouldn't "just" change
my $currentdir = getcwd();
my $dirs = get_profile_cache_dirs();
is_deeply($dirs, {
    resources => "$currentdir/src/test/resources",
    profiles => "$currentdir/target/test/profiles",
    cache => "$currentdir/target/test/cache",
    }, "Default profile_cache directories");

set_profile_cache_options(
    resources => 'src/test/resources/myresources',
    cache => 'target/test/cache/mycache',
);
$dirs = get_profile_cache_dirs();
is($dirs->{resources}, "$currentdir/src/test/resources/myresources",
    "Set and retrieved custom profile_cache resources dir");
is($dirs->{cache}, "$currentdir/target/test/cache/mycache",
    "Set and retrieved custom profile_cache cache dir");

$ccmcfg = Test::Quattor::ProfileCache::get_ccm_config_default();
like($ccmcfg, qr{^cache_root .*/cache/mycache$}m,
     "get_ccm_config_default returned expected config with custom cache_root");


# test rename
is(Test::Quattor::ProfileCache::profile_cache_name("test"), "test",
   "Profilecache name preserves original behaviour");
is(Test::Quattor::ProfileCache::profile_cache_name("$dirs->{resources}/subtree/test.pan"), escape("subtree/test"),
   "Profilecache name handles absolute paths");


# test absolute path
my $profile = "$dirs->{resources}/absprofilecache.pan";
ok (-f $profile, "Found profile $profile");
my $abscfg = prepare_profile_cache($profile);

isa_ok($abscfg, $config_class, "get_config_for_profile returns a $config_class instance for abs profile");

is_deeply($abscfg->getElement("/")->getTree(),
            {test => "data"},
            "getTree of root element returns correct hashref for abs profile");



# Test get_config_for_profile
my $abscfg2 = get_config_for_profile($profile);
is_deeply($abscfg, $abscfg2,
          "get_config_for_profile fecthes same configuration object as returned by prepare_profile_cache for abs profile");


done_testing();
