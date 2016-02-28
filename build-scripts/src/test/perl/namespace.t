use strict;
use warnings;

use Test::More;

use Cwd;
our $orig_inc;

BEGIN {
    # Copy of the original @INC

    $orig_inc = [@INC];
    diag "orig_inc ", explain $orig_inc;

    use Test::Quattor::Namespace;

    INC_insert_namespace('ncm');
}

diag "namespace inserted \@INC ", explain \@INC;

use NCM::Component;



my $ncm_component = $INC{'NCM/Component.pm'};
# prove runs with -I pointing to original code
my $ncm_expected = getcwd()."/src/main/perl/Test/Quattor/namespace/ncm/NCM/Component.pm";
is($ncm_component, $ncm_expected, "NCM::Component provided by inserted ncm namespace");

is_deeply($Test::Quattor::Namespace::inc_orig, $orig_inc, "INC before first modification");
is_deeply($Test::Quattor::Namespace::inc_history, [$orig_inc, $orig_inc],
          "INC history (first is INC from loading the package)");

done_testing();
