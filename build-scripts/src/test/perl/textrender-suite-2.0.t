use strict;
use warnings;

use Test::More;
use Test::Quattor::TextRender;

use Test::Quattor::TextRender::Suite;

use Test::Quattor::Panc qw(set_panc_includepath);

use Cwd qw(abs_path getcwd);

=pod

=head1 DESCRIPTION

Test the TextRender suite unittest.

=cut

# Prepare the namespacepath 
my $tr = Test::Quattor::TextRender->new(
    basepath => getcwd()."/src/test/resources",
    ttpath => 'metaconfig/testservice',
    panpath => 'metaconfig/testservice/pan',
    pannamespace => 'metaconfig/testservice',
);
$tr->make_namespace($tr->{panpath}, $tr->{pannamespace});
set_panc_includepath($tr->{namespacepath}, abs_path($ENV{QUATTOR_TEST_TEMPLATE_LIBRARY_CORE}));

diag("Start actual Suite tests v2.0");

my $base = getcwd()."/src/test/resources";
my $st = Test::Quattor::TextRender::Suite->new(
    relpath => 'metaconfig',
    includepath => $base,
    testspath => "$base/metaconfig/testservice/2.0/tests",
    );

$st->test();

done_testing();
