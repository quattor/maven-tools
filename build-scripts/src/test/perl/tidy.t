use strict;
use warnings;

use Test::More;
use Test::Quattor::Tidy;
use Test::MockModule;

my $mock = Test::MockModule->new('Test::Quattor::Tidy');
my $msgs = [];

my $c = Test::Quattor::Tidy->new(
    codedirs => [qw(src/test/resources/tidy)],
);
isa_ok($c, 'Test::Quattor::Tidy', "is a Test::Quattor::Tidy instance");

$msgs = [];
# informational only for now
$mock->mock('info', sub {shift; push(@$msgs, shift);});

$c->test();

diag explain $msgs;
is(scalar @$msgs, 1, "1 fatal violations");
like($msgs->[0],
     qr{Perltidy failed on src/test/resources/tidy/simple.pl with args .*? noprofile warning-output nostandard-output standard-error-output.*},
     "Expected Perl::Tidy message");

done_testing();
