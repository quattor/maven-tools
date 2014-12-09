use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Quattor::RegexpTest;

use Readonly;

=pod

=head1 DESCRIPTION

Test the RegexpTest test block.

=cut

my $tr = Test::Quattor::RegexpTest->new();

=pod

=head2 regexp flag generation

Test the conversion of flags in regexp flags

=cut

$tr->{flags} = {
    multiline => 1,
    singleline => 1,
    extended => 1,
    renderpath => "/my/path",
    ordered => 1,
};

is($tr->make_re_flags(), "msx", "Conversion msx (casesensitive not present)");

$tr->{flags}->{casesensitive} = 1;

is($tr->make_re_flags(), "msx", "Conversion msx (casesensitive present)");

$tr->{flags}->{casesensitive} = 0;

is($tr->make_re_flags(), "imsx", "Conversion imsx (casensensitive disabled sets caseinsentive reflag)");

is($tr->make_re_flags('multiline'), "isx", "Conversion isx (casensensitive disabled; multiline ignored)");


=pod

=head2 parser tests

Test the parser

=over

=cut 

is_deeply($tr->{tests}, [], "Initial empty tests array ref");


=pod

=item quote

Test quote block

=cut

$tr->{flags} = {quote=>1};
$tr->{tests} = [];
# 4th line intentional trailing whitespace
Readonly my $DATA => <<EOF;
exact text
2nd line ### COUNT 3
 ### Comment
4th line 
EOF

$tr->parse_tests($DATA);
is(scalar @{$tr->{tests}}, 1, "quote gives one test");
is_deeply($tr->{tests}->[0], {reg => qr{(?:^$DATA$)}}, "quote interprets whole block as 1 test");

=pod

=item quote and negate

Check quote and negate combination

=cut

$tr->{flags} = {quote=>1, negate => 1};
$tr->{tests} = [];
$tr->parse_tests($DATA);
is(scalar @{$tr->{tests}}, 1, "quote gives one test");
is_deeply($tr->{tests}->[0], {reg => qr{(?:^$DATA$)}, count => 0}, 
        "quote interprets whole block as 1 test, negate sets count to 0");


=pod

=item quote and negate and extended

Check quote and negate combinatiion; treat whole quote as one extended regexp

=cut

$tr->{flags} = {quote=>1, negate => 1, extended => 1};
$tr->{tests} = [];
$tr->parse_tests($DATA);
is(scalar @{$tr->{tests}}, 1, "quote gives one test");

is_deeply($tr->{tests}->[0], {reg => qr{(?x:^$DATA$)}, count => 0}, 
        "quote interprets whole block as 1 test, negate sets count to 0, extended flag on");

=pod

=item count

Check COUNT

=cut

$tr->{flags} = {};
$tr->{tests} = [];
$tr->parse_tests($DATA);
is_deeply($tr->{tests}, [
            {reg => qr{(?:exact text)}}, 
            {reg => qr{(?:2nd line)}, count => 3}, # trailing whitespace is part of the ### separator!
            {reg => qr{(?:4th line )}},
            ], "data interpreted as 3 tests");


=pod

=item negate and count

Check count 0 for all flags except those with COUNT

=cut

$tr->{flags} = {negate => 1};
$tr->{tests} = [];
$tr->parse_tests($DATA);
is_deeply($tr->{tests}, [
            {reg => qr{(?:exact text)}, count => 0}, 
            {reg => qr{(?:2nd line)}, count => 3}, # COUNT overrides negate
            {reg => qr{(?:4th line )}, count => 0},
            ], "data interpreted as 3 tests with negate");

=pod

=back

=cut

done_testing();
