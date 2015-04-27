use strict;
use warnings;
use Test::More;
use Cwd;

use Test::Quattor::TextRender::Base qw(mock $TARGET_TT_DIR);
use CAF::TextRender;

is($TARGET_TT_DIR, "target/share/templates/quattor",
   "Expected relative TT stage dir");

my $mockinstance = mock();
my $trd = CAF::TextRender->new("whatever", {});
isa_ok($trd, "CAF::TextRender", "TextRender instance");
is($trd->{includepath},
   getcwd()."/$TARGET_TT_DIR",
   "Mocked CAF::TextRender has expected includepath");

$mockinstance->unmock_all();
$trd = CAF::TextRender->new("whatever", {});
isa_ok($trd, "CAF::TextRender", "TextRender instance");
is($trd->{includepath},
   "/usr/share/templates/quattor",
   "Unmocked mocked CAF::TextRender has default includepath");

done_testing();
