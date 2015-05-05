use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Quattor::RegexpTest;

use EDG::WP4::CCM::Element qw(escape);

use Readonly;

Readonly my $FLAGS_NOVALUE => <<'EOF';
multiline
casesensitive
ordered
negate
quote
extended
singleline
EOF

Readonly::Hash my %FLAGS_NOVALUE_HASH => {
    multiline     => 1,
    casesensitive => 1,
    ordered       => 1,
    negate        => 1,
    quote        => 1,
    extended => 1,
    singleline => 1,
    renderpath => '/metaconfig', # added by parser as default
};

Readonly my $FLAGS_VALUE_0 => <<'EOF';
multiline=0
casesensitive=0
ordered=0
negate=0
quote=0
extended=0
singleline=0
EOF

Readonly::Hash my %FLAGS_VALUE_0_HASH => {
    multiline     => 0,
    casesensitive => 0,
    ordered       => 0,
    negate        => 0,
    quote        => 0,
    extended => 0,
    singleline => 0,
    renderpath => '/metaconfig', # added by parser as default
};

Readonly my $FLAGS_VALUE_COMMENT => <<'EOF';
multiline=1
#casesensitive
 ## ordered=0
negate=1
EOF

Readonly::Hash my %FLAGS_VALUE_COMMENT_HASH => {
    multiline => 1,
    negate    => 1,
    renderpath => '/metaconfig', # added by parser as default
};

Readonly my $FLAGS_ALIAS => <<'EOF';
nomultiline
caseinsensitive
unordered
EOF

Readonly::Hash my %FLAGS_ALIAS_HASH => {
    multiline     => 0,
    casesensitive => 0,
    ordered       => 0,
    renderpath => '/metaconfig', # added by parser as default
};

=pod

=head1 DESCRIPTION

Test the RegexpTest unittest flags.

=cut

# Prepare the namespacepath
my $tr = Test::Quattor::RegexpTest->new();

is_deeply(
    $tr->{flags},
    { multiline => 1, ordered => 1, casesensitive => 1,  }, # no renderpath here yet
    "Check default flags"
);

$tr->{flags} = {};
$tr->parse_flags($FLAGS_NOVALUE);
is_deeply( $tr->{flags}, \%FLAGS_NOVALUE_HASH,
    "Check flags without values flags" );

$tr->{flags} = {};
$tr->parse_flags($FLAGS_VALUE_0);
is_deeply( $tr->{flags}, \%FLAGS_VALUE_0_HASH, "Check flags with value 0" );

$tr->{flags} = {};
$tr->parse_flags($FLAGS_VALUE_COMMENT);
is_deeply( $tr->{flags}, \%FLAGS_VALUE_COMMENT_HASH,
    "Check flags with comments" );

$tr->{flags} = {};
$tr->parse_flags($FLAGS_ALIAS);
is_deeply( $tr->{flags}, \%FLAGS_ALIAS_HASH, "Check flags with alias" );

$tr->{flags} = {};
$tr->parse_flags('renderpath=/my/path');
is( $tr->{flags}->{renderpath}, '/my/path', "Check flags renderpath" );

$tr->{flags} = {};
$tr->parse_flags('//my/path/alias');
is( $tr->{flags}->{renderpath},
    '/my/path/alias', "Check flags renderpath alias" );

$tr->{flags} = {};
$tr->parse_flags('metaconfigservice=/my/path');
is(
    $tr->{flags}->{renderpath},
    "/software/components/metaconfig/services/" . escape('/my/path'),
    "Check flags metaconfigservice"
);

$tr->{flags} = {};
$tr->parse_flags('/my/path/alias');
is(
    $tr->{flags}->{renderpath},
    "/software/components/metaconfig/services/" . escape('/my/path/alias'),
    "Check flags metaconfigservice alias"
);


$tr->{flags} = {};
$tr->parse_flags('contentspath=/my/path/to/contents');
is(
    $tr->{flags}->{contentspath},
    '/my/path/to/contents',
    "Check flags contentspath"
);

$tr->{flags} = {};
$tr->parse_flags('rendermodule=mymodule');
is(
    $tr->{flags}->{rendermodule},
    'mymodule',
    "Check flags rendermodule"
);

done_testing();
