# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

package Test::Quattor::TextRender::RegexpTest;

use strict;
use warnings;

# Compatibility with pre ccm-17.2
my $config_class;
BEGIN {
    $config_class = "EDG::WP4::CCM::CacheManager::Configuration";
    local $@;
    eval "use $config_class";
    if ($@) {
        $config_class =~ s/CacheManager:://;
    }
}

use Test::More;

use base qw(Test::Quattor::RegexpTest);

use EDG::WP4::CCM::TextRender;

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

=item ttincludepath

The includepath for CCM::TextRender.

=item ttrelpath

The relpath for CCM::TextRender.

=back

=back

=cut

# Render the text using config and flags-renderpath
# Store the CCM::TextRender instance and the get_text result in attributes
sub render
{
    my ($self) = @_;

    my $renderpath = $self->{flags}->{renderpath};
    # remove single trailing / (could also be the root)
    # $renderpath variable is only used in path join here
    $renderpath =~ s/\/$//;

    my ($module, $contentspath);

    if ($self->{flags}->{rendermodule}) {
        $module = $self->{flags}->{rendermodule};
    } else {
        my $modulepath = "$renderpath/module";
        ok($self->{config}->elementExists($modulepath), "modulepath $modulepath elementExists");

        $module = $self->{config}->getElement($modulepath)->getValue()
    }
    ok($module, "rendermodule specified". ($module || "<undef>"));

    if ($self->{flags}->{contentspath}) {
        $contentspath = $self->{flags}->{contentspath};
    } else {
        $contentspath = "$renderpath/contents";
    }
    ok($contentspath, "contentspath specified". ($contentspath || "<undef>"));
    ok($self->{config}->elementExists($contentspath), "contentspath elementExists");

    ok($self->{ttincludepath}, "ttincludepath specified " . ($self->{ttincludepath} || '<undef>'));
    ok($self->{ttrelpath}, "ttrelpath specified " . ($self->{ttrelpath} || '<undef>'));

    # TODO how to keep this in sync with what metaconfig does? esp the options
    my $opts = {
        eol         => 0,
        relpath     => $self->{ttrelpath},
        includepath => $self->{ttincludepath},
        log         => $self,
    };

    # element flags precede convert settings from renderpath
    if(defined($self->{flags}->{element})) {
        $opts->{element} = $self->{flags}->{element};
    } else {
        my $elementpath = "$renderpath/convert";
        $opts->{element} = $self->{config}->getTree($elementpath);
    }

    $self->{trd} = EDG::WP4::CCM::TextRender->new(
        $module,
        $self->{config}->getElement($contentspath),
        %$opts
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
        $config_class,
        "config $config_class instance"
    );

    # render the text
    my $rp = $self->{flags}->{renderpath};
    ok($self->{config}->elementExists($rp), "Renderpath $rp found");

    $self->render;

    # In case of failure, fail is in the ok message
    ok(defined($self->{text}), "No renderfailure (fail: " . ($self->{trd}->{fail} || "") . ")");
}

1;
