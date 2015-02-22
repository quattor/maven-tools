use strict;
use warnings;

use Test::More;
use Test::Quattor::TextRender::Metaconfig;
use Cwd;

=pod

=head1 DESCRIPTION

Test the metaconfig unittest. This is NOT an example to use 
the Test::Quattor::TextRender::Metaconfig test().

=cut

my $st = Test::Quattor::TextRender::Metaconfig->new(
    service => 'testservice',
    version => '1.0',
    # exception here to set the basepath. Default should be ok for actual usage
    basepath => getcwd()."/src/test/resources/metaconfig",
    );

isa_ok($st, "Test::Quattor::TextRender::Metaconfig", 
       "Returns Test::Quattor::TextRender::Metaconfig instance for service");

# don't do this in real tests unless you have a very good reason.
$st->{expect}->{invalidtt} = [
    'testservice/1.0/failed_syntax.tt',
    'testservice/1.0/tests/profiles/notarealtt.tt', 
    'testservice/pan/notarealtt.tt',
    ];
$st->{expect}->{invalidpan} = [
    'testservice/pan/invalid_name.pan', 
    'testservice/pan/invalid_namespace.pan', 
    'testservice/pan/invalid_type.pan',
    ];

# the actual method to test
$st->test();

done_testing();
