use strict;
use warnings;

use Test::More;

use CAF::Object qw(SUCCESS);
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

=head2 Test mocked filecreation

=cut

my $filebase = "$BASEPATH/files/subdir";
my $filename = "$filebase/file1";

# Test file does not exist (mocked)
ok(! $s->file_exists($filename), "file $filename does not exist");
# Create file with simple_caf
is($s->make_file($filename, $TEXT), SUCCESS, "make_file returns success");

# Check file is instance via get_file
my $fh = get_file($filename);
is("$fh", $TEXT, "make_file made correct file");

# Test file exists
ok($s->file_exists($filename), "mocked file $filename returns true file_exists");
ok(!$s->directory_exists($filename), "mocked file $filename returns false directory_exists");
ok($s->any_exists($filename), "mocked file $filename returns true any_exists");

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

=head2 mock LC and cleanup

=cut

reset_caf_path();

is($s->directory($dirbase), $dirbase, "created directory $dirbase and returned directory name");;
ok($s->directory_exists($dirbase), "directory $dirbase exists");
ok($s->cleanup($BASEPATH, 1, option => 2), "directory $BASEPATH cleaned up");
ok(! $s->directory_exists($dirbase), "directory $dirbase cleanedup (via recursive removal)");
is_deeply($Test::Quattor::caf_path->{cleanup}, [[[$BASEPATH, 1], {option => 2}]],
          "caf_path hash updated after CAF::Path::cleanup");


done_testing();
