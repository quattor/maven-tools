use strict;
use warnings;

use Test::More;

use Cwd;

use EDG::WP4::CCM::Element qw(escape);

use Test::Quattor::ProfileCache qw(prepare_profile_cache 
    get_config_for_profile set_profile_cache_options);
use Test::Quattor::Object qw($TARGET_PAN_RELPATH);
use Test::Quattor::Panc qw(get_panc_includepath);
use Cwd qw(getcwd);
use File::Temp qw(tempdir);
use File::Path qw(mkpath);

# Can't have NoAction here, since no CAF mocking happens
# and otherwise nothing would be written

my $target = getcwd()."/target";
mkpath($target) if ! -d $target;
my $tmp_tlc_dir = tempdir(DIR => $target);

$ENV{QUATTOR_TEST_TEMPLATE_LIBRARY_CORE} = $tmp_tlc_dir;

my $cfg = prepare_profile_cache('profilecache');

isa_ok($cfg, "EDG::WP4::CCM::Configuration", 
            "get_config_for_profile returns a EDG::WP4::CCM::Configuration instance");

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

my $cfg2 = get_config_for_profile('profilecache');
is_deeply($cfg, $cfg2, 
          "get_config_for_profile fecthes same configuration object as returned by prepare_profile_cache");

# verify defaults; they shouldn't "just" change
my $currentdir = getcwd();
my $dirs = Test::Quattor::ProfileCache::get_profile_cache_dirs();
is_deeply($dirs, {
    resources => "$currentdir/src/test/resources",
    profiles => "$currentdir/target/test/profiles",
    cache => "$currentdir/target/test/cache",
    }, "Default profile_cache directories");

set_profile_cache_options(resources => 'src/test/resources/myresources');
$dirs = Test::Quattor::ProfileCache::get_profile_cache_dirs();
is($dirs->{resources}, "$currentdir/src/test/resources/myresources", 
    "Set and retrieved custom profile_cache resources dir");

# test rename
is(Test::Quattor::ProfileCache::profile_cache_name("test"), "test", 
    "Profilecache name preserves original behaviour");
is(Test::Quattor::ProfileCache::profile_cache_name("$dirs->{resources}/subtree/test.pan"), escape("subtree/test"), 
    "Profilecache name handles absolute paths");


# test absolute path
my $profile = "$dirs->{resources}/absprofilecache.pan";
ok (-f $profile, "Found profile $profile");
my $abscfg = prepare_profile_cache($profile);

isa_ok($abscfg, "EDG::WP4::CCM::Configuration", 
            "get_config_for_profile returns a EDG::WP4::CCM::Configuration instance for abs profile");

is_deeply($abscfg->getElement("/")->getTree(), 
            {test => "data"}, 
            "getTree of root element returns correct hashref for abs profile");



# Test get_config_for_profile
my $abscfg2 = get_config_for_profile($profile);
is_deeply($abscfg, $abscfg2, 
          "get_config_for_profile fecthes same configuration object as returned by prepare_profile_cache for abs profile");



done_testing();
