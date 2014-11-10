use strict;
use warnings;

use Test::More;

use Test::Quattor::ProfileCache qw(prepare_profile_cache get_config_for_profile set_panc_options reset_panc_options);

# Can't have NoAction here, since no CAF mocking happens
# and otherwise nothing would be written

set_panc_options(debug => undef);

is_deeply(Test::Quattor::ProfileCache::get_panc_options, {debug => undef}, "Options set");

prepare_profile_cache('profilecache');

my $cfg = get_config_for_profile('profilecache');

isa_ok($cfg, "EDG::WP4::CCM::Configuration", 
            "get_config_for_profile returns a EDG::WP4::CCM::Configuration instance");

is_deeply($cfg->getElement("/")->getTree(), 
            {test => "data"}, 
            "getTree of root element returns correct hashref");

reset_panc_options();

is_deeply(Test::Quattor::ProfileCache::get_panc_options, {}, "Options reset");

done_testing();
