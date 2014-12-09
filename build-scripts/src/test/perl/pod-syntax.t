
use Test::More;
use Test::Pod;

my @dirs = qw(src/main/perl);
all_pod_files_ok(all_pod_files(@dirs));
