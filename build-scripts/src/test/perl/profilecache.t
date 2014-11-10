use strict;
use warnings;

use Test::More;

use Cwd;

use Test::Quattor::ProfileCache qw(prepare_profile_cache get_config_for_profile set_profile_cache_options);

# Can't have NoAction here, since no CAF mocking happens
# and otherwise nothing would be written

my $cfg = prepare_profile_cache('profilecache');

isa_ok($cfg, "EDG::WP4::CCM::Configuration", 
            "get_config_for_profile returns a EDG::WP4::CCM::Configuration instance");

is_deeply($cfg->getElement("/")->getTree(), 
            {test => "data"}, 
            "getTree of root element returns correct hashref");

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

set_profile_cache_options(resources => 'myresources');
$dirs = Test::Quattor::ProfileCache::get_profile_cache_dirs();
is($dirs->{resources}, "$currentdir/myresources", 
    "Set and retrieved custom profile_cache resources dir");

done_testing();
