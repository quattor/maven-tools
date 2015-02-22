use strict;
use warnings;

use Test::More;
use Test::Quattor::Object;

=pod

=head1 DESCRIPTION

Test the Test::Quattor::Object class

=cut

my $dt = Test::Quattor::Object->new(
    x => 'x',
    );

isa_ok($dt, "Test::Quattor::Object", "Returns Test::Quattor::Object instance");

is($dt->{x}, 'x', "Set attribute x");

my @methods = qw(info verbose debug warn error notok gather_pan);
foreach my $method (@methods) {
    ok($dt->can($method), "Object instance has $method method");
}

done_testing();
