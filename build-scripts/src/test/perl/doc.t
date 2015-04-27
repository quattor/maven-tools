use strict;
use warnings;
use Test::More;
use Test::Quattor::Doc;
use Test::MockModule;
use Cwd;

is($DOC_TARGET_PERL, 'target/lib/perl',
   "Expected DOC_TARGET_PERL $DOC_TARGET_PERL");
is($DOC_TARGET_POD, 'target/doc/pod',
   "Expected DOC_TARGET_POD $DOC_TARGET_POD");
is_deeply(\@DOC_TEST_PATHS, [$DOC_TARGET_PERL, $DOC_TARGET_POD],
   "Expected default test directories");

is($DOC_TARGET_PAN, 'target/pan',
   "Expected DOC_TARGET_PAN $DOC_TARGET_PAN");
is($DOC_TARGET_PANOUT, 'target/panannotations',
   "Expected DOC_TARGET_PANOUT $DOC_TARGET_PANOUT");

my ($doc, $ok, $not_ok);

# Can't just test invalid pods easily,
# raises internal tests that would fail
my $mock = Test::MockModule->new('Test::Builder');
$mock->mock('ok', sub {
    my($self, $test, $name) = @_;
    diag("Test ok mocked: ".(defined($test) ? $test : "<undef>"). " $name")
});

$doc = Test::Quattor::Doc->new(
    panpaths => [],
    poddirs => [],
    podfiles => [qw(src/test/resources/doesnotexist.pod src/test/resources/bad.pod)],
    );
($ok, $not_ok) = $doc->pod_files();

# unmock the mocked test class
$mock->unmock_all();

# This is an actual test again
is(scalar @$not_ok, 2,
   "Found 2 invalid pod files (one missing, one syntax error)");
is(scalar @$ok, 0,
   "Found 0 valid pod files");

# Test invalid pan annotation
$doc = Test::Quattor::Doc->new(
    panpaths => [qw(src/test/resources/faultypanannotation)],
    # empty pod should not trigger error (files are empty by default),
    # it means you know you are bypassing pod tests
    poddirs => [],
    );
($ok, $not_ok) = $doc->pan_annotations();
is(scalar @$not_ok, 1, "Found invalid panannotation files");

# Test all ok
my $cwd = getcwd();
ok(chdir('src/test/resources/okpod'),
   "Changed to directory with known ok pod files");

$doc = Test::Quattor::Doc->new(
    podfiles => ['localtest.pod'],
    # all target dirs are in .gitignore, so need to use different paths
    poddirs => [qw(target_tmp/lib/perl target_tmp/doc/pod)],
    panpaths => [qw(target_tmp/pan)],
    panout => "$cwd/target/panannotations",
    );

# Do use it like this, only for testing
($ok, $not_ok) = $doc->pod_files();
is_deeply($ok,
   [qw(localtest.pod target_tmp/lib/perl/module.pm target_tmp/doc/pod/another.pod)],
   "Found expected pod files");
is(scalar @$not_ok, 0, "No invalid pod files");

($ok, $not_ok) = $doc->pan_annotations();
is_deeply($ok,
   [qw(annotate.pan)],
   "Found expected pan files");
is(scalar @$not_ok, 0, "No invalid pan files");

# use it like this
$doc->test();

#
done_testing();
chdir($cwd)
