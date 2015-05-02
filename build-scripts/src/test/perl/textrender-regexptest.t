use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Quattor::TextRender::RegexpTest;

use Test::Quattor::ProfileCache qw(prepare_profile_cache set_profile_cache_options);
use Cwd qw(abs_path getcwd);

use Readonly;

Readonly my $EXPECTED_RENDERTEXT => <<EOF;
default_simple
EXTRA more_simple

EOF

Readonly my $EXPECTED_RENDERTEXT_OVERRIDE => <<EOF;
override
default_override
EXTRA more_override


boolean 1
EOF

Readonly my $EXPECTED_RENDERTEXT_OVERRIDE_OPTS => <<EOF;
override
"default_override"
EXTRA "more_override"


boolean YES
EOF


my $basepath = getcwd()."/src/test/resources";
my $testpath = "$basepath/metaconfig/testservice/1.0/tests";
set_profile_cache_options(resources => "$testpath/profiles");

my $cfg = prepare_profile_cache("$testpath/profiles/nopan.pan");

my $tr = Test::Quattor::TextRender::RegexpTest->new(
    config => $cfg,
    regexp => "$testpath/regexps/nopan/nopan",
    ttrelpath => 'metaconfig',
    ttincludepath => $basepath, 
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

my $srv = $tr->{config}->getElement($tr->{flags}->{renderpath})->getTree();
is_deeply($srv, {
    module => 'testservice/1.0/main',
    contents => {extra => 'more_simple', data => 'default_simple'},
    }, "Correct service subtree of config found");

# render
$tr->render;
isa_ok($tr->{trd}, "EDG::WP4::CCM::TextRender", "EDG::WP4::CCM::TextRender instance saved"); 

ok(! exists($tr->{trd}->{fail}), "No failure (fail: ".($tr->{trd}->{fail} || "").")");

is($tr->{trd}->{module}, $srv->{module}, "Correct module set");


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


#
# override rendermodule / contentspath
#
my $tro = Test::Quattor::TextRender::RegexpTest->new(
    config => $cfg,
    regexp => "$testpath/regexps/nopan/override",
    ttrelpath => 'metaconfig',
    ttincludepath => $basepath, 
);
$tro->parse();
is_deeply($tro->{flags}, {
    casesensitive =>1,
    ordered => 1,
    singleline => 0,
    multiline => 1,
    renderpath => "/metaconfig2",
    rendermodule => "testservice/1.0/override",
    contentspath => "/override/contents"
    }, "Flags found from block and defaults");

$tro->render;
isa_ok($tro->{trd}, "EDG::WP4::CCM::TextRender", "EDG::WP4::CCM::TextRender instance saved"); 
ok(! exists($tro->{trd}->{fail}), "No failure (fail: ".($tro->{trd}->{fail} || "").")");
is($tro->{trd}->{module}, 'testservice/1.0/override', "Correct override module set");
is($tro->{text}, $EXPECTED_RENDERTEXT_OVERRIDE, "override text rendered correctly");
$tro->match();
$tro->postprocess;

#
# override with element opts
#
my $troo = Test::Quattor::TextRender::RegexpTest->new(
    config => $cfg,
    regexp => "$testpath/regexps/nopan/elementopts",
    ttrelpath => 'metaconfig',
    ttincludepath => $basepath, 
);
$troo->parse();
is_deeply($troo->{flags}, {
    casesensitive =>1,
    ordered => 1,
    singleline => 0,
    multiline => 1,
    renderpath => "/metaconfig2",
    rendermodule => "testservice/1.0/override",
    contentspath => "/override/contents",
    element => {'YESNO' => 1, doublequote => 1}
    }, "Flags found from block and defaults");

$troo->render;
isa_ok($troo->{trd}, "EDG::WP4::CCM::TextRender", "EDG::WP4::CCM::TextRender instance saved"); 
ok(! exists($troo->{trd}->{fail}), "No failure (fail: ".($troo->{trd}->{fail} || "").")");
is($troo->{trd}->{module}, 'testservice/1.0/override', "Correct override module set");
is($troo->{text}, $EXPECTED_RENDERTEXT_OVERRIDE_OPTS, "override text with element opts rendered correctly");
$troo->match();
$troo->postprocess;

done_testing();
