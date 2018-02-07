package NCM::Component::Test::Example;

use strict;
use warnings;

# Correct the namespace for Test::Quattor::Component
use parent qw(NCM::Component Exporter);

# reexport NoAction
our @EXPORT = qw($NoAction);
1;
