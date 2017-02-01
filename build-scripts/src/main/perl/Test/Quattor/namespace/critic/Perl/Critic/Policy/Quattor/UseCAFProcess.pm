package Perl::Critic::Policy::Quattor::UseCAFProcess;

# too strict for generic use, that's why installed and to be used via Test::Quattor::Namespace
# You can use it in tests (ending with .t) (where you can't use backticks)

use strict;
use warnings;

use Readonly;

use Perl::Critic::Utils qw{ :severities :classification :ppi };
use parent qw(Perl::Critic::Policy);

# backticks and qx// are handled by InputOutput::ProhibitBacktickOperators
Readonly::Scalar my $DESC => q{Use of system (or backticks)};
Readonly::Scalar my $EXPL => q{Use CAF::Process to simplify unittesting, enable NoActionSupported, logging/reporting};

sub default_severity
{
    return $SEVERITY_HIGHEST;
}

sub default_themes
{
    return qw(quattor);
}

sub applies_to
{
    return 'PPI::Token::Word';
}

sub violates
{
    my ($self, $elem, $doc) = @_;

    # We only need system function call, qx and backtick is covered by InputOutput::ProhibitBacktickOperators
    return if $elem ne 'system';
    return if ! is_function_call($elem);

    if ($doc->can('filename')) {
        # It's ok in tests
        return if $doc->filename =~ m/\.t$/;
    };

    return $self->violation($DESC, $EXPL, $elem);
};

1;
