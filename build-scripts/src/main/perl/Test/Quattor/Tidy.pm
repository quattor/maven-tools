# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

package Test::Quattor::Tidy;

use strict;
use warnings;

use Test::Pod;
use Perl::Tidy;
use Readonly;
use Test::More;
use Test::Quattor::Filetools qw(readfile);
use Text::Diff qw(diff);

use parent qw(Test::Quattor::Object);

# Perltidy options, no leading -- needed
# Use long option names
#   choices: keep vertical alignment
#     there's 'no-valign' to disable it (altough undocumented); but lets try to accept it
Readonly::Array my @DEFAULT_TIDY => (
    'perl-best-practices', # override these defaults by putting the option afterwards (has i=4 ci=4)
    'starting-indentation-level=0', # indentation starts at 0
    'check-syntax',
    'maximum-line-length=120',
    'cuddled-else',
    'noopening-brace-on-new-line', 'opening-sub-brace-on-new-line', # only sub braces on new line
    # no spaces between code and braces
    'paren-tightness=2', 'square-bracket-tightness=2', 'brace-tightness=2', 'block-brace-tightness=2',
);

=pod

=head1 NAME

Test::Quattor::Tidy - Run perltidy.

=head1 DESCRIPTION

This is a class to run perltidy on code with tidy options.

The tidy options are in the perltidy manpage
    man perltidy

=head1 METHODS

=over

=item new

=over

=item codedirs

An arrayref of paths to look for perl code (uses C<Test::Pod::all_pod_files>).

Default is C<target/lib/perl>.

=back

=cut

sub _initialize
{
    my $self = shift;
    $self->{codedirs} = [qw(target/lib/perl)] if ! $self->{codedirs};

    # Don't pass these for now.
    $self->{tidyoptions} = \@DEFAULT_TIDY if (! defined($self->{tidyoptions}));
}

=item check

Run perltidy on filename

=cut

sub check
{
    my ($self, $filename) = @_;

    my ($tidycode, $stderr, @args);

    my @mandatory = (
        'noprofile', # Ignore any .perltidyrc at this site
        'warning-output',
        'nostandard-output',
        'standard-error-output', # append errorfile to stderr / ignores errorfile argument
        );

    # Add all options, mandatory ones last (last one wins)
    push(@args, @{$self->{tidyoptions}}, @mandatory);

    my $code = readfile($filename);

    my $error = Perl::Tidy::perltidy(
        argv        => join(" ", map {"--$_"} @args),
        source      => \$code,
        destination => \$tidycode,
        stderr      => \$stderr,
        );

    if ($error) {
        $self->notok("Perltidy failed on $filename with args @args with error $error stderr $stderr");
    } elsif ($code ne $tidycode) {
        my $diff = diff(\$code, \$tidycode, { STYLE => "Unified" });
        # TODO: switch to notok once the dust settles a bit
        $self->info("Perltidy failed on $filename with args @args with diff\n$diff");
    }
}


=item test

Run critic test on all files found with C<all_pod_files> in all codedirs.

=cut

sub test
{
    my $self = shift;

    foreach my $dir (@{$self->{codedirs}}) {
        $self->notok("codedir $dir is not a directory") if ! -d $dir;
        my @fs = all_pod_files($dir);

        if (@fs) {
            foreach my $file (@fs) {
                $self->check($file);
            }
        } else {
            $self->notok("No code found in directory $dir");
        }
    }
}

=pod

=back

=cut


1;
