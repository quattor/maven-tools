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

Readonly my $DATA => "data";

my $fh = CAF::FileWriter->new($fn);
print $fh $DATA;
$fh->close();

$fh = CAF::FileReader->new($fn);
is("$fh", $DATA, "Reader reads what Writer has written");
$fh->close;

done_testing;
