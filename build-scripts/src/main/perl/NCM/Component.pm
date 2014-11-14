use strict;
use warnings;

package NCM::Component;

# Correct the namespace for Test::Quattor::Component
use base qw(Test::Quattor::Component Exporter);

# reexport NoAction
our @EXPORT = qw($NoAction);

1;
