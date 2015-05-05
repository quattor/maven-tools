use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Quattor::RegexpTest;

use Cwd;

use Readonly;

Readonly my $EXPECTED_RENDERTEXT => <<EOF;
default_simple
EXTRA more_simple

EOF

my $basepath = getcwd()."/src/test/resources";
my $testpath = "$basepath/metaconfig/testservice/1.0/tests";


my $tr = Test::Quattor::RegexpTest->new(
    regexp => "$testpath/regexps/nopan/nopan",
    text => $EXPECTED_RENDERTEXT,
);

# parse
$tr->parse();

is($tr->{description}, "Nopan", "Description found from block");

is_deeply($tr->{flags}, {
    casesensitive =>1,
    ordered => 1,
    singleline => 0,
    multiline => 1,
    renderpath => "/metaconfig2",
    }, "Flags found from block and defaults");

is_deeply($tr->{tests}, [
    {reg => qr{(?m:^default_simple$)} },
    {reg => qr{(?m:^EXTRA more_simple$)} },
    ], "Regexptests found");

is($tr->{text}, $EXPECTED_RENDERTEXT, "Text rendered correctly");

# match
$tr->match;

is(scalar @{$tr->{tests}}, scalar @{$tr->{matches}}, "Match for each test");
is_deeply($tr->{matches}, [
    { before => [0], after => [14], count => 1},
    { before => [15], after => [32], count => 1},
    ], "Expected matches");

# postprocess runs a bunch of tests
$tr->postprocess;


done_testing();
