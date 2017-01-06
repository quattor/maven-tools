#perlcritic --verbose 8 --cruel gives
# [Modules::RequireEndWithOne] Module does not end with "1;" at line 1, column 1.  (Severity: 4)
# [Modules::RequireExplicitPackage] Code not contained in explicit package at line 1, column 1.  (Severity: 4)
# [Modules::RequireVersionVar] No package-scoped "$VERSION" variable found at line 1, column 1.  (Severity: 2)
# [TestingAndDebugging::RequireUseStrict] Code before strictures are enabled at line 1, column 1.  (Severity: 5)
# [TestingAndDebugging::RequireUseWarnings] Code before warnings are enabled at line 1, column 1.  (Severity: 4)
# [TestingAndDebugging::ProhibitNoStrict] Stricture disabled at line 11, column 5.  (Severity: 5)
# [Subroutines::ProhibitExplicitReturnUndef] "return" statement with explicit "undef" at line 3, column 5.  (Severity: 5)
sub abc
{

    no strict refs;
    my $a = 1; # just an example
    use strict refs;

    return undef;
}
