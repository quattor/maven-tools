use strict;
use warnings;

use Test::More;
use Test::Quattor::TextRender;
use Cwd;

=pod

=head1 DESCRIPTION

Test the pan files location and validity

=cut

my $resourcesdir = getcwd()."/src/test/resources";
if ($resourcesdir =~ m/package-build-scripts/) {
    # Handle the case when ran from package-build-scripts
    $resourcesdir =~ s/package-build-scripts/build-scripts/;
};

my $dt = Test::Quattor::TextRender->new(
    basepath => $resourcesdir,
    ttpath => 'metaconfig/testservice',
    panpath => 'metaconfig/testservice/pan',
    pannamespace => 'metaconfig/testservice',
    );

isa_ok($dt, "Test::Quattor::TextRender", "Returns Test::Quattor::TextRender instance for panpath");

# Test private method _verify_relpath
$dt->{test_verify_relpath} = "metaconfig/../../resources/metaconfig/testservice";
$dt->_verify_relpath('test_verify_relpath', $resourcesdir);
is($dt->{test_verify_relpath}, "$resourcesdir/metaconfig/testservice",
    "_verify_relpath returns abs_path with prefix");


my ($pans, $ipans) = $dt->gather_pan($dt->{panpath}, $dt->{pannamespace});
isa_ok($pans, "HASH", "gather_pan returns hash reference to pan templates for panpath");
isa_ok($ipans, "ARRAY", "gather_pan returns array reference to invalid pan templates for panpath");

is(scalar keys %$pans, 3, "Found 3 pan templates for panpath");
is_deeply($pans, {'metaconfig/testservice/pan/schema.pan' => { type => 'declaration', expected => 'metaconfig/testservice/schema.pan'},
                  'metaconfig/testservice/pan/config.pan' => { type => 'unique', expected => 'metaconfig/testservice/config.pan'},
                  'metaconfig/testservice/pan/subtree/more.pan' => { type => 'structure', expected => 'metaconfig/testservice/subtree/more.pan'},
                 }, "Found pan templates with location relative to basepath for panpath");

is(scalar @$ipans, 3, "Found 3 invalid pan templates for panpath");

my @pans_s = sort keys %$pans;
my $copies = $dt->make_namespace($dt->{panpath}, $dt->{pannamespace});
is(scalar @$copies, scalar @pans_s, "All files copied");

$dt->{panunfold} = 0;
$copies = $dt->make_namespace($dt->{panpath}, $dt->{pannamespace});
my @copies_s = sort @$copies;
is_deeply(\@copies_s, \@pans_s, "copies identical made to original with panunfold=0 (.i.e. no copies made)");

done_testing();
