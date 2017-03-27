package test_test;

# a module that ends with .t; to test the usage in system() in tests
# this is not an actual test

use strict;
use warnings;
use version;

our $VERSION = version->new('1.0.0');

system('echo "system in tests is ok"');


1;
