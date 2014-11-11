use strict;
use warnings;

use Test::More;

use Test::Quattor::Panc qw(set_panc_options reset_panc_options get_panc_options get_panc_includepath set_panc_includepath);


set_panc_options(debug => undef);
is_deeply(get_panc_options(), {debug => undef}, "Options set");

is_deeply(get_panc_includepath(), [], "No includepath defined");
my @dirs = qw(/test1 /a b);
set_panc_includepath(@dirs);
is_deeply(get_panc_options()->{"include-path"}, join(":", @dirs), "Includepath set correctly");
is_deeply(get_panc_includepath(), \@dirs, "Includepath retrieved");


reset_panc_options();
is_deeply(get_panc_options(), {}, "Options reset");


done_testing();
