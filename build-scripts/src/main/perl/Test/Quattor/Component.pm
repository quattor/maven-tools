use strict;
use warnings;

=pod

=head1 DESCRIPTION

Backup module, mimicking the base class for all NCM components, but
with no real logic.

=cut

package Test::Quattor::Component;

use parent qw(CAF::Object Exporter);
use Readonly;

our @EXPORT = qw($NoAction);

our $NoAction;

Readonly my $RELATIVE_TEMPLATE_INCLUDE_PATH => 'target/share/templates/quattor';

my $warn_deprecate_escape = 1;

sub _initialize
{
    my ($self, $name, $log) = @_;

    $self->{name} = $name;
    $self->{log} = $log || $main::this_app;

    return 1;
}

no strict 'refs';
foreach my $i (qw(verbose error info ok debug warn report log)) {
    *{$i} = sub {
	my $self = shift;
	$self->{uc($i)}++;
	return $self->{log}->$i(@_) if $self->{log};
    };
    *{ucfirst($i)} = sub {
        warn "Method ", ucfirst($i), " shouldn't be used. Use $i instead";
        return $i->(@_);
    };
}

use strict 'refs';

sub prefix
{
    my $self = shift;

    my @ns = split(/::/, ref($self));
    return "/software/components/$ns[-1]";
}

# A private method only here to disable the deprecation warnings
# of NCM::Component::escape and NCM::Component::unescape
# to allow unittesting these methods (it is the only case where the warnings
# are not required).
# Do NOT disable the warning anywhere else!
sub _disable_warn_deprecate_escape
{
    $warn_deprecate_escape=0;
}

1;
