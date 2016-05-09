use strict;
use warnings;

use Test::More;

use Cwd;
our $orig_inc;

BEGIN {
    # Copy of the original @INC
    # Do it in a separate BEGIN block
    # (the import magic in a Namespace module gets
    # executed when parsing the BEGIN block)
    $orig_inc = [@INC];
    diag "orig_inc ", explain $orig_inc;
}

BEGIN {
    use Test::Quattor::Namespace qw(ncm);
}

diag "namespace inserted \@INC ", explain \@INC;

use NCM::Component;



my $ncm_component = $INC{'NCM/Component.pm'};

# prove runs with -I pointing to original code
my $pwd = getcwd();
$pwd =~ s/\/$//;

my $ncm_expected = "src/main/perl/Test/Quattor/namespace/ncm/NCM/Component.pm";
if ($ncm_component =~ m/^\//) {
    $ncm_expected = "$pwd/$ncm_expected";
};

if ($pwd =~ m/package-build-scripts/) {
    # Handle the case when ran from package-build-scripts
    # Test in package-build-script use the target code
    $ncm_expected =~ s/src\/main/target\/lib/;
}

is($ncm_component, $ncm_expected, "NCM::Component provided by inserted ncm namespace");

is_deeply($Test::Quattor::Namespace::inc_orig, $orig_inc, "INC before first modification");
is_deeply($Test::Quattor::Namespace::inc_history, [$orig_inc, $orig_inc],
          "INC history (first is INC from loading the package)");

done_testing();
