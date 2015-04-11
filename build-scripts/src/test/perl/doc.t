use strict;
use warnings;
use Test::More;
use Test::Quattor::Doc;
use Cwd;

is($DOC_TARGET_PERL, 'target/lib/perl', 
   "Expected DOC_TARGET_PERL $DOC_TARGET_PERL");
is($DOC_TARGET_POD, 'target/doc/pod', 
   "Expected DOC_TARGET_POD $DOC_TARGET_POD");
is_deeply(\@DOC_TEST_PATHS, [$DOC_TARGET_PERL, $DOC_TARGET_POD], 
   "Expected default test directories");

my $cwd = getcwd();
ok(chdir('src/test/resources/okpod'), 
   "Changed to directory with known ok pod files");

my $doc = Test::Quattor::Doc->new(
    podfiles => ['localtest.pod'],
    # all target dirs are in .gitignore, so need to use different paths
    poddirs => [qw(target_tmp/lib/perl target_tmp/doc/pod)],
    );
# Do use it like this, only for testing
my ($ok, $not_ok) = $doc->all_pod_files_ok();
is_deeply($ok, 
   [qw(localtest.pod target_tmp/lib/perl/module.pm target_tmp/doc/pod/another.pod)],
   "Found expected pod files");
is(scalar @$not_ok, 0, "No invalid pod files");

# use it like this
$doc->test();

# 
done_testing();
chdir($cwd)
