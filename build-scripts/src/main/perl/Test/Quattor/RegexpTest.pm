# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}

use strict;
use warnings;

package Test::Quattor::RegexpTest;

use Test::More;

use base qw(Test::Quattor::Object);

use EDG::WP4::CCM::Element qw(escape);

use Readonly;

# Blocks are separated using this separator
Readonly my $BLOCK_SEPARATOR => qr{^-{3}$}m;

# Number of expected blocks
Readonly my $EXPECTED_BLOCKS => 3;

Readonly my $DEFAULT_FLAG_RENDERPATH => '/metaconfig';

Readonly::Hash my %DEFAULT_FLAGS => {
    multiline     => 1,
    casesensitive => 1,
    ordered       => 1,
};

# convert these flag names in respective regexp flags
Readonly::Hash my %FLAGS_REGEXP_MAP => {
    multiline     => 'm',
    casesensitive => 'i',    # actually this is caseinsensitive
    extended      => 'x',
    singleline    => 's',
};

Readonly my $METACONFIG_SERVICES => "/software/components/metaconfig/services/";

=pod

=head1 NAME

Test::Quattor::RegexpTest - Class to handle a single regexptest.

=head1 DESCRIPTION

This class parses and executes the tests as described in a single regexptest.

=head2 Public methods

=over

=item new

Returns a new object, accepts the following options

=over

=item regexp

The regexptest file.

=item text

The text to test.

=back

=cut

sub _initialize
{
    my ($self) = @_;

    $self->{flags}   = {%DEFAULT_FLAGS};
    $self->{tests}   = [];
    $self->{matches} = [];

    return $self;
}

=pod

=head2 parse

Parse the regexp file in 3 sections: description, flags and tests.

Each section is converted in an instance attribute named 'description',
 'flags' and 'tests'.

=cut

sub parse
{
    my ($self) = @_;

    # cut textfile in 3 blocks
    open REG, $self->{regexp};
    my @blocks = split($BLOCK_SEPARATOR, join("", <REG>));
    close REG;

    is(scalar @blocks, $EXPECTED_BLOCKS, "Expected number of blocks");

    $self->parse_description($blocks[0]);

    $self->parse_flags($blocks[1]);

    $self->parse_tests($blocks[2]);

}

=pod

=head2 parse_description

Parse the description block and set the description attribute.

First argument C<blocktxt> is the 1st block of the regexptest file.

=cut

sub parse_description
{
    my ($self, $blocktxt) = @_;

    my $description = $blocktxt;
    $description =~ s/\s+/ /g;
    $description =~ s/^\s+|\s+$//g;

    $self->{description} = $description;

}

=pod

=head2 parse_flags

Parse the flags block and set C<flags> attribute

Following flags are supported

=over

=item regul expression flags:

=over

=item multiline 

(no)multiline / multiline=1/0

=item singleline

singleline / singleline=1/0 

(This flag can coexist with multiline)

=item extended format

extended / extended=1/0

=item case senistive

case(in)sensistive / casesensitive = 0/1

=back

=item order flag

=over

=item ordered matches

(un)ordered / ordered=0/1

=back 

=item negate

negate / negate = 0/1

Negate all regexps, none of the regexps can match 
(is an alias for C<COUNT 0> on every regtest;
 overwritten when COUNT is set for individual regexp)

=item quote

quote / quote = 0/1

Whole tests block is 1 regular expression. With C<quote> flag set,
C<multiline> flag is logged and ignored; C<ordered> flag is 
meaningless (and silently ignored).

=item location of module and contents settings:

=over

=item metaconfigservice=/some/path

Also any flag starting with C</> is interpreted as C<metaconfigservice>

=item renderpath=/some/path

Also any flag starting with C<//> is interpreted as C<renderpath>

=back

=item Default settings

    ordered=1
    multiline=1
    casesensitive=1
    renderpath=/metaconfig

=back

First argument C<blocktxt> is the 2nd block of the regexptest file.

=cut

sub parse_flags
{
    my ($self, $blocktxt) = @_;

    foreach my $line (split("\n", $blocktxt)) {
        next if ($line =~ m/^\s*$/);
        if ($line =~ m/^\s*#+\s*(.*)\s*$/) {
            $self->verbose("flag commented: $1");
        } elsif ($line =~
            m/^\s*(multiline|casesensitive|ordered|negate|quote|singleline|extended)(?:\s*=\s*(0|1))?\s*$/
            )
        {
            $self->{flags}->{$1} = defined($2) ? $2 : 1;
        } elsif ($line =~
            m/^\s*(?:no(?<s>multiline)(?<t>))|(?:(?<s>case)in(?<t>sensitive))|(?:un(?<s>ordered)(?<t>))\s*$/
            )
        {
            # yeah, not so pretty...
            $self->{flags}->{"$+{s}$+{t}"} = 0;
        } elsif ($line =~ m/^\s*(metaconfigservice|renderpath)\s*=\s*(\S+)\s*$/) {
            $self->{flags}->{$1} = $2;
        } elsif ($line =~ m/^\s*(?<r>\/)?(?<path>\/\S*)\s*$/) {
            $self->{flags}->{$+{r} ? 'renderpath' : 'metaconfigservice'} = $+{path};
        } else {
            $self->notok("Unallowed flag $line");
        }
    }

    if (exists($self->{flags}->{metaconfigservice})) {

        # remove the metaconfigservice
        my $ms = delete $self->{flags}->{metaconfigservice};
        if (exists($self->{flags}->{renderpath})) {
            $self->notok("Both renderpath and metaconfigservice flags defined. Keeping renderpath");
        } else {
            $self->{flags}->{renderpath} = $METACONFIG_SERVICES . escape($ms);
        }
    }
    $self->{flags}->{renderpath} = $DEFAULT_FLAG_RENDERPATH if (!$self->{flags}->{renderpath});
}

# Create the regexp flags from the flags atribute.
# Ignores all flags passed as arguments
# Returns string
sub make_re_flags
{
    my ($self, @ignore) = @_;

    my @reflags;
    while (my ($flag, $reflag) = each %FLAGS_REGEXP_MAP) {
        my $val = $self->{flags}->{$flag};
        next if (!defined($val));
        next if (grep {$flag eq $_} @ignore);
        $val = $val ? 0 : 1 if ($flag eq 'casesensitive');
        push(@reflags, $reflag) if $val;
    }

    return join("", sort @reflags);
}

=pod

=head2 parse_tests

Parse the tests block and set C<tests> attribute

If the C<quote> flag is set, the whole tests block is 
seen as one big regular expression, and rendered text 
has to be an exact match, incl EOF newline etc.

Without the C<quote> flag set, the tests are parsed line by line, 
and seen as one regexp per line.

Lines starting with C<\s*#{3} > (trailing space!) are comments.

Lines ending with C<\s#{3}> are interpreted as having options set. 
Supported options 
=over

=item COUNT

C<COUNT \d+> is the exact number of matches 
(use C<COUNT 0 >to make sure a line doesn't match).

This is a global count, e.g. in ordered mode the count 
itself is not number of matches since previous test match.

=back

The first argument C<blocktxt> is the 3rd block of the regexptest file

=cut

sub parse_tests
{
    my ($self, $blocktxt) = @_;

    if ($self->{flags}->{quote}) {

        # TODO why would we ignore this? we can use \A/\B instead of ^/$
        # TODO is quote a regexp or literal match (with eq operator)?
        $self->verbose("multiline set but ignored with quote flag") if $self->{flags}->{multiline};
        my $flags = $self->make_re_flags('multiline');
        my $test = {reg => qr{(?$flags:^$blocktxt$)}};
        $test->{count} = 0 if $self->{flags}->{negate};
        push(@{$self->{tests}}, $test);

        # return here to avoid extra indentation
        return;
    }

    foreach my $line (split("\n", $blocktxt)) {
        next if ($line =~ m/^\s*$/);
        if ($line =~ m/^\s*#{3}+\s*(.*)\s*$/) {
            $self->verbose("regexptest test commented: $1");
            next;
        }

        my $flags = $self->make_re_flags();
        my $test  = {};

        $test->{count} = 0 if $self->{flags}->{negate};

        # parse any special options
        if ($line =~ m/^(.*)\s#{3}+\s(?:(?:COUNT\s(?<count>\d+)))\s*$/) {
            if (exists($+{count})) {
                $test->{count} = $+{count};
            }

            # redefine line
            $line = $1;
        }

        # make regexp
        $test->{reg} = qr{(?$flags:$line)};

        # add test
        push(@{$self->{tests}}, $test);
    }
}

# Preprocess the text (or even render the text)
# based on the available flags and/or description.
# Also additional tests can be added.
# The end result should stored in the C<text> attribute.
# The method is called in the C<test> without arguments
# before the C<match> method
sub preprocess
{
    # Method from base class does nothing.
}

# Match all tests against the text attribute
# Store matches begin and end position in matches attribute
# for each match of each test; and the number of matches as count
sub match
{
    my ($self) = @_;

    foreach my $test (@{$self->{tests}}) {

        # always make all matches for the whole text
        my $remainder = $self->{text};
        my (@before, @after);
        my $count = 0;
        while ($remainder =~ /$test->{reg}/g) {
            push(@before, $-[0]);
            push(@after,  $+[0]);
            $count++;
        }
        push(@{$self->{matches}}, {before => \@before, after => \@after, count => $count});
    }
}

# Postprocess the matched results
#   verify count
#   verify ordered
# Does not return anything
sub postprocess
{
    my ($self) = @_;

    my $nrtests = scalar @{$self->{tests}};

    # the position of the end of previous match
    my $lastpos = -1;
    foreach my $idx (0 .. $nrtests - 1) {
        my $test  = $self->{tests}->[$idx];
        my $match = $self->{matches}->[$idx];
        my $msg   = "for test idx $idx (pattern $test->{reg})";

        # Verify that the (global) count is ok.
        if (exists($test->{count})) {
            is($test->{count}, $match->{count},
                "Number of matches as expected (test $test->{count} match $match->{count}) $msg");
        } else {

            # there should be at least one match
            ok($match->{count} > 0,
                "Found at least one match (total $match->{count} matches) $msg");
        }

        # In ordered mode, we check that there is a match after the match of the previous test
        #   This allows multiple matches (or even repeated tests).
        if ($self->{flags}->{ordered}) {
            my $orderok = 0;    # order not ok by default
            my ($before, $after) = (-1, -1);
            foreach my $midx (0 .. $match->{count} - 1) {
                $before = $match->{before}->[$midx];
                $after  = $match->{before}->[$midx];
                if ($before > $lastpos) {
                    $orderok = 1;

                    # non greedy, take the endpos of the first match
                    # that comes after the previous match
                    last;
                }
            }

            ok($orderok, "Order ok $msg (lastpos $lastpos before $before)");

            # if current test fails the ordering, the lastpos is not updated
            $lastpos = $after if $orderok;
        }
    }
}

=pod

=head2 test

Perform the tests as defined in the flags and specified in the 'tests' section

=cut

sub test
{
    my ($self) = @_;

    ok(-f $self->{regexp}, "Regexp file $self->{regexp} found.");

    $self->parse;

    $self->info("BEGIN test for $self->{description}");

    # render the text
    my $rp = $self->{flags}->{renderpath};
    ok($self->{config}->elementExists($rp), "Renderpath $rp found");

    $self->preprocess;

    ok(defined($self->{text}), "Text to test defined");

    # run the regexps over the text
    $self->match;

    is(scalar @{$self->{tests}}, scalar @{$self->{matches}}, "Match for each test");

    # this runs a bunch of extra tests
    $self->postprocess;

    $self->info("END test for $self->{description}");
}

1;
