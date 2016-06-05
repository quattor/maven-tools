use strict;
use warnings;

use Test::More;

use Test::Quattor;

use CAF::Object;
$CAF::Object::NoAction = 1;

use CAF::FileWriter;
use CAF::FileReader;

use Readonly;
use Cwd;

my $ccfgtmp = getcwd() . "/target/tmp/";
my $fn = "$ccfgtmp/test_quattor_mock_write";
my $fn2 = "$ccfgtmp/test_quattor_mock_write2";

Readonly my $DATA => "data";

my $fh = CAF::FileWriter->new($fn);
print $fh $DATA;
my $changed = $fh->close();
is($changed, undef, "New file, so contents changed, NoAction set");

# use new instance, no close/destroy magic?
my $fh2 = CAF::FileWriter->new($fn);
print $fh2 $DATA;
$changed = $fh2->close();
is($changed, undef, "Same file, same data, so contents not changed, NoAction set");

# diff should be reported now
set_caf_file_close_diff(1);

my $fh3 = CAF::FileWriter->new($fn2);
print $fh3 $DATA;
$changed = $fh3->close();
ok($changed, "New file, so contents changed, NoAction and caf_file_close_diff set");

# use new instance, no close/destroy magic?
my $fh4 = CAF::FileWriter->new($fn2);
print $fh4 $DATA;
$changed = $fh4->close();
ok(!$changed, "Same file, same data, NoAction and caf_file_close_diff set");

my $fh5 = CAF::FileWriter->new($fn2);
print $fh5 $DATA x 2;
$changed = $fh5->close();
ok($changed, "Same file, new data, NoAction and caf_file_close_diff set");

my $fh6 = CAF::FileWriter->new($fn2, backup => '.old');
print $fh6 $DATA x 3;
$changed = $fh6->close();
ok($changed, "Same file, new data, backup, NoAction and caf_file_close_diff set");

#
# Read what has been written
#

$fh = CAF::FileReader->new($fn);
is("$fh", $DATA, "Reader reads what Writer has written");
$fh->close;

$fh = CAF::FileReader->new("$fn2");
is("$fh", $DATA x 3, "Reader reads what Writer fh6 has written");
$fh->close;

$fh = CAF::FileReader->new("$fn2.old");
# backup is fh5
is("$fh", $DATA x 2, "Reader reads what Writer fh6 has written as backup");
$fh->close;

done_testing;
