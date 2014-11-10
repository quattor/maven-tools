use strict;
use warnings;

use Test::More;

use Test::Quattor::Panc qw(set_panc_options reset_panc_options);

set_panc_options(debug => undef);

is_deeply(Test::Quattor::Panc::get_panc_options(), {debug => undef}, "Options set");

reset_panc_options();

is_deeply(Test::Quattor::Panc::get_panc_options(), {}, "Options reset");


done_testing();
