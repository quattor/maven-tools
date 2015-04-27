# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;

package Test::Quattor::TextRender;

use File::Basename;
use File::Copy;
use File::Find;
use File::Temp qw(tempdir);
use Cwd qw(abs_path getcwd);
use Test::More;

use Carp qw(croak);
use File::Path qw(mkpath);

use Template::Parser;

use base qw(Test::Quattor::Object);

use Readonly;

Readonly my $DEFAULT_NAMESPACE_DIRECTORY => "target/textrender/namespace";

=pod

=head1 NAME

Test::Quattor::TextRender - Class for unittesting
the TextRender templates.

=head1 DESCRIPTION

This class should be used whenever to unittest templates
that can be processed via TextRender. (For testing ncm-metaconfig
templates looked at the derived Test::Quattor::TextRender::Metaconfig
class).

=head2 Public methods

=over

=item new

Returns a new object, accepts the following options

=over

=item basepath

Basepath that points to the templates.

=item ttpath

Path to the TT files.
If the path is not absolute, search from basepath.

=item panpath

Path to the (mandatory) pan templates.
If the path is not absolute, search from basepath.

=item pannamespace

Namespace for the (mandatory) pan templates. (Use empty
string for no namespace).

=item namespacepath

Destination directory to create a copy of the pan templates
in correct namespaced directory. Relative paths are assumed
relative to the current working directory.

If no value is set, a random directory will be used.

=item panunfold

Boolean to force or disable the "unfolding" of the pan templates
in the namespacepath with correct pannamespace. Default is true.

The C<make_namespace> method  takes care of the actual unfolding (if any).

=item expect

Expect is a hash reference to bypass some built-in tests
in the test methods.

Use with care, better to fix the actual problem.
(No attempt is made to make this any userfriendly;
main reason of existence is to unittest
these test modules).

=item invalidtt

Array reference of invalid TT files to pass the C<test_gather_tt> test method.

=item invalidpan

Array reference of invalid pan templates to pass the C<test_gather_pan> test method.

=back

=back

=cut

sub _initialize
{
    my ($self) = @_;

    # support caching
    $self->{cache} = {};

    $self->_sanitize();
}

# _verify_relpath
sub _verify_relpath
{
    my ($self, $key, $prefix) = @_;

    if ($self->{$key} !~ m/^\//) {
        $self->verbose("Relative $key ".$self->{$key}." found; prefix $prefix");
        $self->{$key} = "$prefix/".$self->{$key};
    }
    $self->verbose("Checking $key ".$self->{$key}." with abs_path");
    my $abspath = abs_path($self->{$key});
    if(defined($abspath) && -d $abspath) {
        $self->verbose("Found abspath $abspath for $key");
    } else {
        $self->notok("$key ".$self->{$key}." returns invalid abs_path ".($abspath || "<undef>"));
        $abspath = "/not/valid/$key"; # avoid undef issues
    }
    $self->{$key} = $abspath;
}


# sanity checks, validates some internals, return nothing
sub _sanitize
{
    my ($self) = @_;

    $self->{basepath} = abs_path($self->{basepath});
    ok(-d $self->{basepath}, "basepath $self->{basepath} exists");

    if ($self->{ttpath}) {
        $self->_verify_relpath('ttpath', $self->{basepath});
    } else {
        $self->notok("Init without ttpath");
    }

    if($self->{skippan}) {
        $self->verbose("Skippan enabled");
    } else {
        if ($self->{panpath}) {
            $self->_verify_relpath('panpath', $self->{basepath});
        } else {
            $self->notok("Init without panpath");
        }

        ok(defined($self->{pannamespace}),
           "Using init pannamespace $self->{pannamespace}");

        my $currentdir = getcwd();
        if (defined($self->{namespacepath})) {
            $self->_verify_relpath('namespacepath', $currentdir);
        } else {
            my $dest = "$currentdir/$DEFAULT_NAMESPACE_DIRECTORY";
            if (!-d $dest) {
                mkpath($dest)
                    or croak "Init Unable to create parent namespacepath directory $dest $!";
            }

            $self->{namespacepath} = tempdir(DIR => $dest);
        }
        ok(-d $self->{namespacepath}, "Init namespacepath $self->{namespacepath} exists");

        if (! defined($self->{panunfold})) {
            $self->{panunfold} = 1;
        }
        ok(defined($self->{panunfold}), "panunfold $self->{panunfold}");
    }

}

=pod

=head2 gather_tt

Walk the C<ttpath> and gather all TT files
A TT file is a text file with an C<.tt> extension;
they are considered 'invalid' when they are
in a 'test' or 'pan' directory or
when they fail syntax validation.

Returns an arrayreference with path
(relative to the basepath) of TT and invalid TT files.

=cut

sub gather_tt
{
    my ($self) = @_;

    my $cache = $self->{cache};

    return $cache->{tts}, $cache->{invalid_tts} if $cache->{tt};

    my @tts;
    my @invalid_tts;

    my $relpath = $self->{basepath};

    my $wanted = sub {
        my $name = $File::Find::name;
        $name =~ s/^$relpath\/+//;
        if (-T && m/\.(tt)$/) {
            if ($name !~ m/(^|\/)(pan|tests)\//) {
                my $tp = Template::Parser->new({});
                open TT, $_;
                if ($tp->parse(join("", <TT>))) {
                    push(@tts, $name);
                } else {
                    $self->verbose("failed syntax validation TT $name with " . $tp->error());
                    push(@invalid_tts, $name);
                }
                close TT;
            } else {
                push(@invalid_tts, $name);
            }
        }
    };

    find( {
        wanted => $wanted,
        preprocess => sub { return sort { $a cmp $b } @_ },
    },  $self->{ttpath});

    $cache->{tts}         = \@tts;
    $cache->{invalid_tts} = \@invalid_tts;

    return $cache->{tts}, $cache->{invalid_tts};
}

=pod

=head2 test_gather_tt

Run tests based on gather_tt results; returns nothing.

=cut

sub test_gather_tt
{
    my ($self) = @_;

    my ($tts, $invalid_tts) = $self->gather_tt();

    my $ntts = scalar @$tts;
    ok($ntts, "found $ntts TT files in ttpath $self->{ttpath}");
    $self->verbose("found $ntts TT files: ", join(", ", @$tts));

    # Fail test and log any invalid TTs
    my $msg = "invalid TTs " . join(', ', @$invalid_tts);
    if ($self->{expect}->{invalidtt}) {
        is_deeply($invalid_tts, $self->{expect}->{invalidtt}, "Expected $msg");
    } else {
        is(scalar @$invalid_tts, 0, "No $msg");
    }
}

=pod

=head2 gather_pan

Same as Test::Quattor::Object C<gather_pan>, but with <relpath> set
to the instance 'basepath'. (With C<panpath> and C<pannamespace> as arguments)

=cut

sub gather_pan
{
    my ($self, $panpath, $pannamespace) = @_;

    my $cache = $self->{cache};

    return $cache->{pans}, $cache->{invalid_pans} if $cache->{pans};

    my ($pans, $invalid_pans) =
        $self->SUPER::gather_pan($self->{basepath}, $panpath, $pannamespace);

    $cache->{pans}         = $pans;
    $cache->{invalid_pans} = $invalid_pans;

    return $cache->{pans}, $cache->{invalid_pans};
}

=pod

=head2 make_namespace

Create a copy of the gathered pan files from C<panpath> in the correct C<pannamespace>.
Directory structure is build up starting from the instance C<namespacepath> value.

Returns an arrayreference with the copy locations.

If the C<panunfold> attribute is true, a copy of the pan templates is placed
in the expected subdirectory under the C<namespacepath>.
If C<panunfold> attribute is false, the pan templates are assumed to be in the
correct location, and nothing is done.

=cut

sub make_namespace
{
    my ($self, $panpath, $pannamespace) = @_;

    my ($pans, $ipans) = $self->gather_pan($panpath, $pannamespace);

    my @copies;
    while (my ($pan, $value) = each %$pans) {
        my $dest;
        if ($self->{panunfold}) {

            # pan is relative wrt basepath; copy it to $destination/
            $dest = "$self->{namespacepath}/$value->{expected}";
            my $destdir = dirname($dest);
            if (!-d $destdir) {
                mkpath($destdir)
                    or croak "make_namespace Unable to create directory $destdir $!";
            }

            my $src;
            if ($pan =~ m/^\//) {
                $src = $pan;
                $self->verbose("Absolute pan source $src dest $dest");
            } else {
                $src = "$self->{basepath}/$pan";
                $self->verbose("Pan source $src from relative $pan dest $dest");
            }
            copy($src, $dest) or die "make_namespace: Copy $src to $dest failed: $!";
        } else {
            $dest = $pan;
            $self->verbose("No unfold of pantemplate $dest.");
        }
        push(@copies, $dest);
    }

    return \@copies;

}

=pod

=head2 test_gather_pan

Run tests based on gather_pan results; returns nothing.

(C<panpath> and C<pannamespace> can be passed as arguments to
override the instance values).

=cut

sub test_gather_pan
{
    my ($self, $panpath, $pannamespace) = @_;

    if($self->{skippan}) {
        $self->verbose("Skippan enabled");
        return;
    }

    $panpath      = $self->{panpath}      if !defined($panpath);
    $pannamespace = $self->{pannamespace} if !defined($pannamespace);

    my ($pans, $invalid_pans) = $self->gather_pan($panpath, $pannamespace);

    my $npans = scalar keys %$pans;
    ok($pans, "found $npans pan templates in panpath $panpath");
    $self->verbose("found $npans pan templates: ", join(", ", keys %$pans));

    # Fail test and log any invalid pan templates
    my $msg = "invalid pan templates " . join(', ', @$invalid_pans);
    if ($self->{expect}->{invalidpan}) {
        is_deeply($invalid_pans, $self->{expect}->{invalidpan}, "Expected $msg");
    } else {
        is(scalar @$invalid_pans, 0, "No $msg");
    }

    # there must be one declaration template called schema.pan in the panpath
    my $schema = "$panpath/schema.pan";
    $schema =~ s/^$self->{basepath}\/+//;
    is($pans->{$schema}->{type}, "declaration", "Found schema $schema");

    # there can be no object templates
    while (my ($pan, $value) = each %$pans) {
        $self->notok("No object template $pan found.") if ($value->{type} eq 'object');
    }

    my $copies = $self->make_namespace($self->{panpath}, $self->{pannamespace});
    is(scalar @$copies, scalar keys %$pans, "All files copied to $self->{namespacepath}");

}

1;
