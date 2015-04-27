use strict;
use warnings;

use Test::More;
use Cwd;
use Test::Quattor::Panc qw(set_panc_options reset_panc_options
    get_panc_options get_panc_includepath set_panc_includepath
    panc panc_annotations);


set_panc_options(debug => undef);
is_deeply(get_panc_options(), {debug => undef}, "Options set");

is_deeply(get_panc_includepath(), [], "No includepath defined");
my @dirs = qw(/test1 /a b);
set_panc_includepath(@dirs);
is_deeply(get_panc_options()->{"include-path"}, join(":", @dirs),
    "Includepath set correctly");
is_deeply(get_panc_includepath(), \@dirs, "Includepath retrieved");

reset_panc_options();
is_deeply(get_panc_options(), {}, "Options reset");

# Test compilation
my $currentdir = getcwd();
is(panc('quattor.pan', 'src/test/resources', 'target/pancout'),
   0, "panc succes");
# panc does chdir to resourcedir
is(getcwd(), $currentdir, "Back in original directory");
ok(-f "target/pancout/quattor.json", "Found compiled JSON file");

# Test annotations
is(panc_annotations('src/test/resources', 'target/pancannotationsout', ['quattor.pan']),
   0, "panc-annotations succes");
ok(-f "target/pancannotationsout/quattor.pan.annotation.xml", "Found annotation file");

done_testing();
