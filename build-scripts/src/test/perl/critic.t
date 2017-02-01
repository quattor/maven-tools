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
is(scalar @$msgs, 9, "9 fatal violations");
my $all_text = join("\n", @$msgs);
like($all_text,
     qr{Failed policy violation src/test/resources/critic/test.pl 2 Modules::RequireVersionVar },
     "Expected Perl::Critic Modules::RequireVersionVar messages");

like($all_text,
     qr{Failed policy violation src/test/resources/critic/quattor_policy.pl 5 Quattor::UseCAFProcess },
     "Expected Perl::Critic Quattor::UseCAFProcess messages picks up custom quattor policies");


done_testing();
