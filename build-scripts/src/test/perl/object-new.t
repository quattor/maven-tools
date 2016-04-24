use strict;
use warnings;

use Test::More;
use Test::Quattor::Object;

=pod

=head1 DESCRIPTION

Test the Test::Quattor::Object class

=head2 new

Test new

=cut


my $dt = Test::Quattor::Object->new(
    x => 'x',
    is_verbose => 1,
    get_debuglevel => 3,
    );

isa_ok($dt, "Test::Quattor::Object", "Returns Test::Quattor::Object instance");

is($dt->{x}, 'x', "Set attribute x");

my @methods = qw(info verbose report debug warn error notok gather_pan is_verbose is_quiet get_debuglevel event);
foreach my $method (@methods) {
    ok($dt->can($method), "Object instance has $method method");
}

=pod

=head2 logging

Test logging methods

=cut

$dt->loghist_reset();
$dt->loghist_add('FAKE1', "Message1-1");
$dt->loghist_add('FAKE2', "Message2-1");
$dt->loghist_add('FAKE1', "Message1-2");


my @msgs;
@msgs=$dt->loghist_get('FAKE1');
is_deeply(\@msgs, ['Message1-1', 'Message1-2'], "Correct history for type FAKE1");
is($dt->{LOGCOUNT}->{FAKE1}, 2, "Correct LOGCOUNT for type FAKE1");
is($dt->{LOGLATEST}->{FAKE1}, 'Message1-2', "Correct LOGLATEST for type FAKE1");

@msgs=$dt->loghist_get('FAKE2');
is_deeply(\@msgs, ['Message2-1'], "Correct history for type FAKE2");
is($dt->{LOGCOUNT}->{FAKE2}, 1, "Correct LOGCOUNT for type FAKE2");
is($dt->{LOGLATEST}->{FAKE2}, 'Message2-1', "Correct LOGLATEST for type FAKE2");

$dt->loghist_reset();
is_deeply($dt->{LOGCOUNT}, {}, "LOGCOUNT reset");
is_deeply($dt->{LOGLATEST}, {}, "LOGLATEST reset");
ok(!defined($dt->loghist_get('FAKE1')), "loghist reset");

$dt->debug(2, "message1");
$dt->verbose("message1");
$dt->report("message1");
$dt->info("message1");
$dt->warn("message1");
$dt->error("message1");
# event is not supposed to be used like this
$dt->event($dt, message => 'somemessage');

is_deeply($dt->{LOGCOUNT}, {
    'DEBUG', 1,
    'VERBOSE', 1,
    'REPORT', 1,
    'INFO', 1,
    'WARN', 1,
    'ERROR', 1,
    'EVENT', 1,
}, "Expected LOGCOUNT");

is_deeply($dt->{LOGLATEST}, {
    'DEBUG', '2 message1',
    'VERBOSE', 'message1',
    'REPORT', 'message1',
    'INFO', 'message1',
    'WARN', 'message1',
    'ERROR', 'message1',
    'EVENT', {message => 'somemessage', _objref => 'Test::Quattor::Object'},
}, "Expected LOGLATEST");

is($dt->is_quiet(), 0, "is_quiet returns 0 (default, not defined)");
is($dt->is_verbose(), 1, "is_verbose returns 1 (as defined)");
is($dt->get_debuglevel(), 3, "get_debuglevel returns 3 (as defined)");

done_testing();
