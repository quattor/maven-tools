use strict;
use warnings;

# No done_testing;
# Test::NoWarnings is (also) loaded as part of CommonDeps
# it has a destroy/cleaned method to does the magic
# (and doesn't like done_testing here)
# the 2nd test is from Test::NoWarnings::had_no_warnings
use Test::More tests => 2;
use Test::NoWarnings;

use Test::Quattor::CommonDeps;

Test::NoWarnings::clear_warnings();

# Not much to test
ok(1, "Could load Test::Quattor::CommonDeps");
