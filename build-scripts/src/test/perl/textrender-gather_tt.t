use strict;
use warnings;

use Test::More;
use Test::Quattor::TextRender;
use Cwd;

=pod

=head1 DESCRIPTION

Test the TT files location 

=head2 Direct TT path 

Using direct TT path

=cut

my $dt = Test::Quattor::TextRender->new(
    basepath => getcwd()."/src/test/resources",
    ttpath => 'metaconfig/testservice',
    panpath => 'metaconfig/testservice/pan',
    pannamespace => 'metaconfig/testservice',
    );

isa_ok($dt, "Test::Quattor::TextRender", "Returns Test::Quattor::TextRender instance for direct ttpath");

my ($tts, $itts) = $dt->gather_tt();
isa_ok($tts, "ARRAY", "gather_tt returns array reference to TTs for direct ttpath");
isa_ok($itts, "ARRAY", "gather_tt returns array reference to invalid TTs for direct ttpath");

is(scalar @$tts, 4, "Found 4 TT files for direct ttpath");
is_deeply($tts, [
    'metaconfig/testservice/1.0/main.tt', 
    'metaconfig/testservice/1.0/extra.tt',
    'metaconfig/testservice/2.0/main.tt', 
    'metaconfig/testservice/2.0/extra.tt',
    ], "Found TT files with location relative to basepath for direct ttpath");

is(scalar @$itts, 3, "Found 2 invalid TT files for direct ttpath");


done_testing();
