use strict;
use warnings;

use Test::More;

use Test::Quattor::ProfileCache qw(prepare_profile_cache get_config_for_profile);

# Can't have NoAction here, since no CAF mocking happens
# and otherwise nothing would be written

prepare_profile_cache('profilecache');

my $cfg = get_config_for_profile('profilecache');

isa_ok($cfg, "EDG::WP4::CCM::Configuration", 
            "get_config_for_profile returns a EDG::WP4::CCM::Configuration instance");

is_deeply($cfg->getElement("/")->getTree(), 
            {test => "data"}, 
            "getTree of root element returns correct hashref");

done_testing();
