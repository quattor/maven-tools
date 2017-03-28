use strict;
use warnings;

use Test::More;

use CAF::Object qw(SUCCESS CHANGED);
use Test::Quattor;
use Test::Quattor::Object;

use simple_caf;

use CAF::Object;
$CAF::Object::NoAction = 1;

use Readonly;
Readonly my $BASEPATH => "/some/where";

Readonly my $TEXT => 'my text';

is_deeply({ %Test::Quattor::files_contents },
          {'/' => $Test::Quattor::DIRECTORY },
          "/-directory added to start");

my $obj = Test::Quattor::Object->new();
my $s = simple_caf->new(log => $obj);

isa_ok($s, "simple_caf", "simple_caf instance created");

# Mocked ok() function required by some tests involving
# execution of a failed ok() call
my $ok;
my $mocked_ok = sub {
    my($self, $test, $name) = @_;
    diag("Test ok mocked: ".(defined($test) ? $test : "<undef>"). " $name");
    $ok = "$test $name";
};
my $mock_test_builder = Test::MockModule->new('Test::Builder');

=head2 Test mocked filecreation

=cut

my $filebase = "$BASEPATH/files/subdir";
my $filename = "$filebase/file1";

# Test file does not exist (mocked)
ok(! $s->file_exists($filename), "file $filename does not exist");
ok(! $s->is_symlink($filename), "is_symlink returns false (file $filename does not exist)");
# Create file with simple_caf
is($s->make_file($filename, $TEXT), SUCCESS, "make_file returns success");

# Check file is instance via get_file
my $fh = get_file($filename);
is("$fh", $TEXT, "make_file made correct file");

# Test file exists
ok($s->file_exists($filename), "mocked file $filename returns true file_exists");
ok(!$s->directory_exists($filename), "mocked file $filename returns false directory_exists");
ok($s->any_exists($filename), "mocked file $filename returns true any_exists");
ok(! $s->is_symlink($filename), "mocked file $filename returns false is_symlink");

# Test creation of basedir of filename
ok(!$s->file_exists($filebase), "mocked dir $filebase returns false file_exists");
ok($s->directory_exists($filebase), "mocked dir $filebase returns true directory_exists");
ok($s->any_exists($filebase), "mocked dir $filebase returns true any_exists");

# Recreate same file, return exists
is($s->make_file($filename, $TEXT), $simple_caf::EXISTS, "make_file returns EXISTS 2nd time");

# use set_file_contents, check file exists and undef is returned on dir
ok(! defined(set_file_contents($filebase, "woohoo")), "cannot set_file_contents if destination is a directory");
$filebase = "$filebase/subdir2";
$filename = "$filebase/file2";
is(set_file_contents($filename, "woohoo"), "woohoo", "set_file_contents sets adn returns contents");
ok($s->file_exists($filename), "mocked file $filename returns true file_exists after set_file_contents");
ok($s->directory_exists($filebase), "mocked base dir $filebase returns true directory_exists after set_file_contents");

=head2 Test mocked directory creation

=cut

my $dirbase = "$BASEPATH/dirs/subdir";

# verify dir does not exist
ok(!$s->directory_exists($dirbase), "mocked missing dir $dirbase returns false directory_exists");
# create dir
is($s->make_directory($dirbase), SUCCESS, "make_directory returns success");
ok($s->directory_exists($dirbase), "mocked dir $dirbase returns true directory_exists");

# check caf_path hashref
is_deeply($Test::Quattor::caf_path->{directory}, [[[qw(/some/where/dirs/subdir)], {}]],
          "caf_path hash updated after CAF::Path::directory");

$Test::Quattor::caf_path->{test} = [qw(1 2 3)];
reset_caf_path('directory');
is_deeply($Test::Quattor::caf_path, {directory => [], test => [qw(1 2 3)]},
          "reset_caf_path only resets the named item");
reset_caf_path();
is_deeply($Test::Quattor::caf_path, {},
          "reset_caf_path resets all if no named item is passed");

# recreate dir return EXISTS
is($s->make_directory($dirbase), $simple_caf::EXISTS, "make_directory returns EXISTS 2nd time");

# test recursive paths
my $tmppath = '';
foreach my $p (split(/\//, $dirbase)) {
    $tmppath="$tmppath/$p";
    ok($s->directory_exists($tmppath), "mocked dir $tmppath returns true directory_exists for recursive check");
}

# remove_any directory
ok(remove_any($BASEPATH), "succesful removal of BASEPATH directory");
ok(!$s->directory_exists($BASEPATH), "mocked missing dir $dirbase returns false directory_exists after removal");

is_deeply([sort keys %Test::Quattor::files_contents ], [qw(/ /some)],
          "recursively removed $BASEPATH dir");

is_deeply({ %Test::Quattor::desired_file_contents }, {}, "entries in desired_file_contents are also deleted");


=head2 Test mocked symlink creation

=cut

my $targetbase = "$BASEPATH/files";
my $linkbase = "$BASEPATH/files/subdir";
my $symlink1 = "$linkbase/symlink1";
my $symlink2 = "$linkbase/symlink2";
my $target1 = "$targetbase/target1";
my $target2 = "$targetbase/target2";
my $target3 = "$targetbase/target3";
my $unexisting_target = "$targetbase/unexisting_target";
my $dirtest = "$targetbase/dirtest";
is($s->make_file($target1, "Link tests: target1"), SUCCESS, "make_file returns success for $target1");
is($s->make_file($target2, "Link tests: target2"), SUCCESS, "make_file returns success for $target2");
is($s->make_file($target3, "Link tests: target3"), SUCCESS, "make_file returns success for $target3");
is($s->make_directory($dirtest, "Link tests: dirtest"), SUCCESS, "make_directory returns success for $dirtest");

is($s->symlink($target1, $symlink1), CHANGED, "Symlink $symlink1 successfully created");
ok($s->is_symlink($symlink1), "$symlink1 is a symlink");
is($s->symlink($target1, $symlink1), SUCCESS, "Symlink $symlink1 already exists with the right target");
ok($s->is_symlink($symlink1), "$symlink1 is still a symlink");
is($s->symlink($target2, $symlink1), CHANGED, "Symlink $symlink1 has been successfully updated");
ok($s->is_symlink($symlink1), "$symlink1 is still a symlink after being updated");

# The following tests will cause a ok() call to fail: mock ok() to intercept it
# Global variable $ok contains the ok() arguments as a string
$mock_test_builder->mock('ok', $mocked_ok);
$s->symlink($target2, $target3);
$mock_test_builder->unmock_all();
is($ok,
   "0 File $target3 already exists and option 'force' not specified",
   "$target3 is a file: cannot be updated to a symlink without 'force'");

my %opts;
$opts{invalid_option} = 1;
$mock_test_builder->mock('ok', $mocked_ok);
$s->symlink($target2, $target3, %opts);
$mock_test_builder->unmock_all();
is($ok,
   "0 Invalid option (invalid_option) passed to _make_link()",
   "symlink() invalid option triggers a test failure");
delete $opts{invalid_option};

$opts{check} = 1;
$mock_test_builder->mock('ok', $mocked_ok);
$s->symlink($unexisting_target, $symlink2, %opts);
$mock_test_builder->unmock_all();
is($ok,
   "0 Symlink target ($unexisting_target) doesn't exist",
   "symlink() fails if target doesn't exist with check=1");
delete $opts{check};

$mock_test_builder->mock('ok', $mocked_ok);
$s->symlink($target1, $dirtest);
$mock_test_builder->unmock_all();
is($ok,
   "0 $dirtest already exists and is not a symlink",
   "symlink() fails if target exiss and is not a file or symlink");


$opts{force} = 1;
is($s->symlink($target2, $target3, %opts), CHANGED, "$target3 updated to a symlink ('force' option present)");
ok($s->is_symlink($target3), "$target3 is a symlink");

$opts{keeps_state} = 1;
is($s->symlink($target2, $target3, %opts), SUCCESS, "symlink: 'keeps_state' option is accepted");


=head2 Test mocked hardlink creation

=cut

my $hardlink1 = "$linkbase/hardlink1";
my $hardlink2 = "$linkbase/hardlink2";

is($s->hardlink($target1, $hardlink1), CHANGED, "Hardlink $hardlink1 successfully created");
ok($s->has_hardlinks($hardlink1), "$hardlink1 is a hardlink");
ok($s->is_hardlink($target1, $hardlink1), "$hardlink1 and $target1 are hardlinked");
is($s->hardlink($target1, $hardlink1), SUCCESS, "Hardlink $hardlink1 already exists with the right target");
ok($s->has_hardlinks($hardlink1), "$hardlink1 is still a hardlink");
ok($s->is_hardlink($hardlink1, $target1), "$hardlink1 and $target1 remain hardlinked");
is($s->hardlink($target2, $hardlink1), CHANGED, "Hardlink $hardlink1 has been successfully updated");
ok($s->has_hardlinks($hardlink1), "$hardlink1 is still a hardlink after being updated");
ok($s->is_hardlink($target2, $hardlink1), "$hardlink1 and $target2 are hardlinked");


=head2 mock LC and cleanup

=cut

reset_caf_path();

is($s->directory($dirbase), $dirbase, "created directory $dirbase and returned directory name");;
ok($s->directory_exists($dirbase), "directory $dirbase exists");
ok($s->cleanup($BASEPATH, 1, option => 2), "directory $BASEPATH cleaned up");
ok(! $s->directory_exists($dirbase), "directory $dirbase cleanedup (via recursive removal)");
is_deeply($Test::Quattor::caf_path->{cleanup}, [[[$BASEPATH, 1], {option => 2}]],
          "caf_path hash updated after CAF::Path::cleanup");


=head2 mock move

=cut

reset_caf_path();

my $src = "/test/move/src/file";
my $dest = "/test/move/dest/file";
set_file_contents($src, "source");
set_file_contents($dest, "dest");

ok($s->file_exists($src), "src $src exists");
ok($s->file_exists($dest), "dest $dest exists");

ok($s->move($src, $dest, '.old', option => 2), "move ok");
ok(!$s->file_exists($src), "src $src does not exists");
ok($s->file_exists($dest), "dest $dest exists");
ok($s->file_exists("$dest.old"), "dest backup $dest.old exists");

is_deeply($Test::Quattor::caf_path->{move}, [[[$src, $dest, '.old'], {option => 2}]],
          "caf_path hash updated after CAF::Path::move");

=head mock _listdir

=cut

$s->make_file("/listdir/test", "abc");
$s->directory("/listdir/dir");
$s->directory("/listdir/testdir");
set_file_contents("/listdir/anothertest", "source");

is_deeply($s->_listdir("/listdir", sub {return $_[0] =~ m/test/;}),
          [qw(anothertest test testdir)],
          "_listdir returns entries from files_contents and desired_file_contents and applies test function");

done_testing();
