package quattor_policy;

use strict;
use warnings;
use version;

our $VERSION = version->new('1.0.0');

# Only quattor policy violations

sub caf_process
{
    # 3 violations:
    # UseCAFProcess
    system('the usual');

    # ProhibitBacktickOperators
    `backticks are so kewl`;

    # ProhibitBacktickOperators
    qx/hello obscure/;

};


1;
