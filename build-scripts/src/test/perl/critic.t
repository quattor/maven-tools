use strict;
use warnings;

use Test::More;
use Test::Quattor::Critic;
use Test::MockModule;

my $mock = Test::MockModule->new('Test::Quattor::Critic');
my $msgs = [];

my $c = Test::Quattor::Critic->new(
    codedirs => [qw(src/test/resources/critic)],
);
isa_ok($c, 'Test::Quattor::Critic', "is a Test::Quattor::Critic instance");

$msgs = [];
$mock->mock('notok', sub {shift; push(@$msgs, shift);});

$c->test();

diag explain $msgs;
is(scalar @$msgs, 6, "5 fatal violations");
like($msgs->[0],
     qr{Failed policy violation src/test/resources/critic/test.pl Modules::RequireVersionVar },
     "Expected Perl::Critic messages");

done_testing();
