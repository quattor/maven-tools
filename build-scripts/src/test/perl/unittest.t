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

is_deeply(\@Test::Quattor::Unittest::TESTS, [qw(load doc tt critic tidy)],
          'ordered tests as expected');

$u->read_cfg();
is($u->{cfg}->{notarealtestsection}->{a}, 'b', 'expected value from merge main TQU');

# check defaults, all tests enabled apart from linters
foreach my $test (@Test::Quattor::Unittest::TESTS) {
    my $expected_state = 1;
    if ($test eq 'critic' || $test eq 'tidy') {
        $expected_state = 0;
    };
    is($u->{cfg}->{$test}->{enable}, $expected_state, "Default config has test $test enabled");
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
