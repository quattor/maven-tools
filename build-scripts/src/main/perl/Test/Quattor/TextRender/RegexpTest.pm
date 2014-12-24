# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}

use strict;
use warnings;

package Test::Quattor::TextRender::RegexpTest;

use Test::More;

use base qw(Test::Quattor::RegexpTest);

use CAF::TextRender;

=pod

=head1 NAME

Test::Quattor::TextRender::RegexpTest - Class to handle a single regexptest
and the input text is rendered rather then passed.

=head1 DESCRIPTION

This class parses and executes the tests as described in a single regexptest.
It inherits from Test::Quattor::RegexpTest with main difference that the 
text to test is rendered rather then passsed.

=head2 Public methods

=over

=item new

Returns a new object, accepts the following options

=over

=item regexp

The regexptest file.

=item config

The configuration instance to retreive the values from.

=item includepath

The includepath for CAF::TextRender.

=item relpath

The relpath for CAF::TextRender.

=back

=back

=cut

# Render the text using config and flags-renderpath
# Store the CAF::TextRender instance and the get_text result in attributes
sub render
{
    my ($self) = @_;

    my $srv = $self->{config}->getElement($self->{flags}->{renderpath})->getTree();

    ok($self->{includepath}, "includepath specified " . ($self->{includepath} || '<undef>'));
    ok($self->{relpath}, "relpath specified " . ($self->{relpath} || '<undef>'));

    # TODO how to keep this in sync with what metaconfig does? esp the options
    $self->{trd} = CAF::TextRender->new(
        $srv->{module},
        $srv->{contents},
        eol         => 0,
        relpath     => $self->{relpath},
        includepath => $self->{includepath},
        log         => $self,
    );

    $self->{text} = $self->{trd}->get_text;
    if (defined($self->{text})) {
        $self->verbose("Rendertext:\n$self->{text}");
    }
}

# Implement the preprocess method by rendering the text as defined in the flags
sub preprocess
{
    my ($self) = @_;
    isa_ok(
        $self->{config},
        "EDG::WP4::CCM::Configuration",
        "config EDG::WP4::CCM::Configuration instance"
    );

    # render the text
    my $rp = $self->{flags}->{renderpath};
    ok($self->{config}->elementExists($rp), "Renderpath $rp found");

    $self->render;

    # In case of failure, fail is in the ok message
    ok(defined($self->{text}), "No renderfailure (fail: " . ($self->{trd}->{fail} || "") . ")");
}

1;

