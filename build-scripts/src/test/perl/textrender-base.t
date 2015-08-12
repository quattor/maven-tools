use strict;
use warnings;
use Test::More;
use Cwd;

use Test::Quattor::TextRender::Base qw(mock_textrender $TARGET_TT_DIR);
use EDG::WP4::CCM::TextRender;

is($TARGET_TT_DIR, "target/share/templates/quattor",
   "Expected relative TT stage dir");

my $mockinstance = mock_textrender();
my $trd = EDG::WP4::CCM::TextRender->new("whatever", {});
isa_ok($trd, "EDG::WP4::CCM::TextRender", "TextRender instance");
is_deeply($trd->{includepath},
          [getcwd()."/$TARGET_TT_DIR"],
          "EDG::WP4::CCM::TextRender with mocked CAF::TextRender has expected includepath");

$mockinstance->unmock_all();
$trd = EDG::WP4::CCM::TextRender->new("whatever", {});
isa_ok($trd, "EDG::WP4::CCM::TextRender", "TextRender instance");
is_deeply($trd->{includepath},
          ["/usr/share/templates/quattor"],
          "EDG::WP4::CCM with unmocked mocked CAF::TextRender has default includepath");

done_testing();
