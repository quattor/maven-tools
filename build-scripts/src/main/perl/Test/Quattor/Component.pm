use strict;
use warnings;

=pod

=head1 DESCRIPTION

Backup module, mimicking the base class for all NCM components, but
with no real logic.

=cut

package Test::Quattor::Component;

use parent qw(CAF::Object Exporter);
use Template;
use Template::Stash;
use Readonly;

our @EXPORT = qw($NoAction);

our $NoAction;
$Template::Stash::PRIVATE = undef;

Readonly my $RELATIVE_TEMPLATE_INCLUDE_PATH => 'target/share/templates/quattor';

sub _initialize
{
    my ($self, $name, $log) = @_;

    $self->{name} = $name;
    $self->{log} = $log || $main::this_app;

    $self->{template} = Template->new(
        INCLUDE_PATH => $RELATIVE_TEMPLATE_INCLUDE_PATH,
        #DEBUG => 'undef',
	);

    return 1;
}

sub template
{
    my $self = shift;
    return $self->{template};
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

sub unescape
{
    my ($self, $str) = @_;

    warn "Called unescape through the component. This will be removed soon.",
         "Please upgrade your code to use the version supplied by EDG::WP4::CCM::Element.";

    $str =~ s!(_[0-9a-f]{2})!sprintf("%c",hex($1))!eg;
    return $str;
}

sub escape
{
    my ($self, $str) = @_;

    warn "Called escape() through the component. This will be removed soon.",
        "Please upgrade your code to use the version supplied by EDG::WP4::CC::Element.";

    $str =~ s/(^[0-9]|[^a-zA-Z0-9])/sprintf("_%lx", ord($1))/eg;
    return $str;
}

1;
