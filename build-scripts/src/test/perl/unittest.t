use strict;
use warnings;

use Test::More;

# No BEGIN is required, tests are not run on import
our $TQU = <<'EOF';
[notarealtestsection]
a=b
EOF

# This is to test the unitest code
use Test::Quattor::Unittest qw(notest);

my $u = Test::Quattor::Unittest->new();
isa_ok($u, 'Test::Quattor::Unittest');

is_deeply(\@Test::Quattor::Unittest::TESTS, [qw(load)],
          'ordered tests as expected');

$u->read_cfg();
is($u->{cfg}->{notarealtestsection}->{a}, 'b', 'expected value from merge main TQU');

# check defaults, all tests enabled
foreach my $test (@Test::Quattor::Unittest::TESTS) {
    ok($u->{cfg}->{$test}->{enable}, "Default config has test $test enabled");
    ok($u->can($test), "Test $test method found");
}

# modules
is_deeply($u->_get_modules(), [], "No modules guessed/configured");

my $cfg = {
    prefix => 'a::b::',
    modules => 'c,d::e,:,f'
};
is_deeply($u->_get_modules($cfg), [qw(a::b::c a::b::d::e a::b a::b::f)],
          "configured modules with prefix");


done_testing;
