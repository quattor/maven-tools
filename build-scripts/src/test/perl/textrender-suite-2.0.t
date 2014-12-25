use strict;
use warnings;

use Test::More;
use Test::Quattor::TextRender;

use Test::Quattor::TextRender::Suite;

# only use it like this for this particular unittest
use Test::Quattor::TextRender::Base;

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

diag("Start actual Suite tests v2.0");

my $base = getcwd()."/src/test/resources";
my $st = Test::Quattor::TextRender::Suite->new(
    ttrelpath => 'metaconfig',
    ttincludepath => $base,
    testspath => "$base/metaconfig/testservice/2.0/tests",
    );

set_panc_includepath($tr->{namespacepath}, 
    Test::Quattor::TextRender::Base::get_template_library_core($st));

$st->test();

done_testing();
