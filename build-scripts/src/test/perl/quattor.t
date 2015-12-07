use strict;
use warnings;

use Test::More;

# Test the import method
use Test::Quattor qw(quattor);

use CAF::Service;

use CAF::Object;
$CAF::Object::NoAction = 1;

my $cfg = get_config_for_profile('quattor');

isa_ok($cfg, "EDG::WP4::CCM::Configuration", 
            "get_config_for_profile returns a EDG::WP4::CCM::Configuration instance");

is_deeply($cfg->getElement("/")->getTree(), 
            {test => "data"}, 
            "getTree of root element returns correct hashref");

is(CAF::Service::os_flavour(), 'linux_sysv', 'Test::Quattor sets linux_sysv by default');
set_service_variant('linux_systemd');
is(CAF::Service::os_flavour(), 'linux_systemd', 'linux_systemd set as variant');

done_testing();
