use strict;
use warnings;

use Test::More;

# Test the import method
use Test::Quattor qw(quattor);

use CAF::Object;
$CAF::Object::NoAction = 1;

my $cfg = get_config_for_profile('quattor');

isa_ok($cfg, "EDG::WP4::CCM::Configuration", 
            "get_config_for_profile returns a EDG::WP4::CCM::Configuration instance");

is_deeply($cfg->getElement("/")->getTree(), 
            {test => "data"}, 
            "getTree of root element returns correct hashref");

done_testing();
