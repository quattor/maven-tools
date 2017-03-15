use strict;
use warnings;

use Test::More;
use Test::Quattor::Filetools qw(writefile readfile);

use File::Temp qw(tempdir);
my $dir = tempdir( CLEANUP => 1 );

my $dest = "$dir/base1/file1";
$dest = "$dir/base1/file2";

writefile($dest);
ok(-f $dest, "writefile created correct file incl parent dir");
is(readfile($dest), $Test::Quattor::Filetools::DEFAULT_CONTENT,
   "read default content of writefile");

$dest = "$dir/base1/file2";

my $tstcnt = "0";
writefile($dest, $tstcnt);
ok(-f $dest, "writefile created correct file incl parent dir");
is(readfile($dest), $tstcnt, "read written content of writefile");

done_testing();
