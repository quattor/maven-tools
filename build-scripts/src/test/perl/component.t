use strict;
use warnings;

BEGIN {
    use Test::Quattor::Namespace;
    INC_insert_namespace('ncm');
}

# Test if the code provided by Test::Quattor::Component
# can be used and is equal to the NCM::Component from the
# provided one via the ncm namespace

use Test::More;
use Test::Quattor::Component;
use NCM::Component;

use EDG::WP4::CCM::Element qw(escape unescape);

# Only to be used in this unittest
Test::Quattor::Component::_disable_warn_deprecate_escape();

my $test_comp = Test::Quattor::Component->new();
my $ncm_comp = NCM::Component->new();

# A method to run shared tests on Test::Quattor::Component and NCM::Component
sub test
{
    my ($inst, $name) = @_;

    isa_ok($inst, $name, "Created a $name instance");

    my @methods = qw(info verbose debug error report warn prefix);
    foreach my $method (@methods) {
        ok($inst->can($method), "$name instance has $method method");
    }
}

test($test_comp, "Test::Quattor::Component");
test($ncm_comp, "NCM::Component");


done_testing();
