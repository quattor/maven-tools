use strict;
use warnings;

use Test::More;

use Test::Quattor;
use Test::Quattor::Object;

$Test::Quattor::NoAction = 1;

use simple_caf;
use CAF::Object qw(CHANGED);

use CAF::FileWriter;
use CAF::FileReader;

use Readonly;
use Cwd;

my $obj = Test::Quattor::Object->new();
my $s = simple_caf->new(log => $obj);

my $ccfgtmp = getcwd() . "/target/tmp/";
my $fn = "$ccfgtmp/test_quattor_mock_write";
my $fn2 = "$ccfgtmp/test_quattor_mock_write2";

Readonly my $DATA => "data";

my $fh = CAF::FileWriter->new($fn, log => $obj);
print $fh $DATA;
my $changed = $fh->close();
ok($changed, "New file, so contents changed, NoAction set");

# use new instance, no close/destroy magic?
my $fh2 = CAF::FileWriter->new($fn, log => $obj);
print $fh2 $DATA;
$changed = $fh2->close();
ok(!$changed, "Same file, same data, so contents not changed, NoAction set");

my $fh5 = CAF::FileWriter->new($fn2, log => $obj);
print $fh5 $DATA x 2;
$changed = $fh5->close();
ok($changed, "Same file, new data, NoAction set");

my $fh6 = CAF::FileWriter->new($fn2, backup => '.old', log => $obj);
print $fh6 $DATA x 3;
$changed = $fh6->close();
ok($changed, "Same file, new data, backup, NoAction set");

#
# Read what has been written
#

$fh = CAF::FileReader->new($fn, log => $obj);
is("$fh", $DATA, "Reader reads what Writer has written");
$fh->close;

$fh = CAF::FileReader->new("$fn2", log => $obj);
is("$fh", $DATA x 3, "Reader reads what Writer fh6 has written");
$fh->close;

$fh = CAF::FileReader->new("$fn2.old", log => $obj);
# backup is fh5
is("$fh", $DATA x 2, "Reader reads what Writer fh6 has written as backup");
$fh->close;

# Editor source
my $efn = "/test/fileditor/toedit";
my $source_data = "the source";
my $edit_data = "to edit";
set_file_contents("/test/fileditor/source", $source_data);
set_file_contents($efn, $edit_data);

$fh = CAF::FileEditor->new($efn, log => $obj);
is("$fh", $edit_data, "FileEditor sets contents from set_file_contents on init");
ok(!$fh->close(), "no diff on FileEditor open/close");

my $efh = get_file($efn);
isa_ok($efh, 'CAF::FileEditor', "FileEditor returns a CAF::FileEditor instance");
is("$efh", $edit_data, "get_file FileEditor has edit content");

$fh = CAF::FileEditor->new("/test/fileditor/toedit", source => "/test/fileditor/source", log => $obj);
is("$fh", $source_data, "FileEditor sets source contents from set_file_contents on init");
ok($fh->close(), "diff on FileEditor close with source");

$efh = get_file($efn);
isa_ok($efh, 'CAF::FileEditor', "FileEditor returns a CAF::FileEditor instance with source");
is("$efh", $source_data, "get_file FileEditor has source content");

# test reading symlink/hardlink
my $efns = "$efn.symlink";
my $efnh = "$efn.hardlink";
is($s->symlink($efn, $efns), CHANGED, "Symlink $efns successfully created");
is($s->hardlink($efn, $efnh), CHANGED, "Hardlink $efnh successfully created");

$fh = CAF::FileReader->new($efns, log => $obj);
is("$fh", $source_data, "Reader reads symlinked FileEditor $efns");

$fh = CAF::FileReader->new($efnh, log => $obj);
is("$fh", $source_data, "Reader reads hardlinked FileEditor $efnh");


done_testing;
