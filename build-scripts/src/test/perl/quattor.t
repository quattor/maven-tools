use strict;
use warnings;

use Test::More;

# Test the import method
use Test::Quattor qw(quattor);
use Test::MockModule;
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

# Test warn_is_ok

# Mock the ok call
# This is the default
my $ok;

my $mocked_ok = sub {
    my($self, $test, $name) = @_;
    diag("Test ok mocked: ".(defined($test) ? $test : "<undef>"). " $name");
    $ok = "$test $name";
};

my $mock = Test::MockModule->new('Test::Builder');
$mock->mock('ok', $mocked_ok);

warn "a perl warning default";

# unmock the mocked test class
$mock->unmock_all();

like($ok, qr{0 Perl warning: a perl warning default at },
     "warn triggers a failing test by default");

# warnings are ok
warn_is_ok();
warn "a perl warning undef (this is a test of a warning; please ignore)";
warn_is_ok(1);
warn "a perl warning 1 (this is a test of a warning; please ignore)";

# warnings are not ok
warn_is_ok(0);

$mock->mock('ok', $mocked_ok);

warn "a perl warning 0";

# unmock the mocked test class
$mock->unmock_all();

like($ok, qr{0 Perl warning: a perl warning 0 at },
     "warn triggers a failing test with warn_is_ok(0)");


done_testing();
