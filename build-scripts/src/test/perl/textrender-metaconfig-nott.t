use strict;
use warnings;

use Test::More;
use Test::Quattor::TextRender::Metaconfig;
use Cwd;

=pod

=head1 DESCRIPTION

Test the metaconfig unittest on non-TT example. 
This is NOT an example to use the Test::Quattor::TextRender::Metaconfig test().

=cut

my $st = Test::Quattor::TextRender::Metaconfig->new(
    service => 'nottservice',
    usett => 0, 
    # exception here to set the basepath. Default should be ok for actual usage
    basepath => getcwd()."/src/test/resources/metaconfig",
    );

isa_ok($st, "Test::Quattor::TextRender::Metaconfig", 
       "Returns Test::Quattor::TextRender::Metaconfig instance for service");

# the actual method to test
$st->test();

done_testing();
