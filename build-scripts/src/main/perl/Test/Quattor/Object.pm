# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}

use strict;
use warnings;

package Test::Quattor::Object;

our @ISA;
use Test::More;

use File::Basename;
use File::Find;
use Cwd 'abs_path';

sub new
{
    my $that  = shift;
    my $proto = ref($that) || $that;
    my $self  = {@_};

    bless($self, $proto);

    $self->_initialize();

    return $self;
}

sub _initialize
{
    # nothing to do here
}

=pod

=head2 info    

info-type logger, calls diag. 
Arguments are converted in message, prefixed with 'INFO'.

=cut

sub info
{
    my ($self, @args) = @_;
    my $msg = join('', @args);
    diag("INFO $msg");
    return $msg;
}

=pod

=head2 verbose

verbose-type logger, calls note
Arguments are converted in message, prefixed with 'VERBOSE'.

=cut

sub verbose
{
    my ($self, @args) = @_;
    my $msg = join('', @args);
    note("VERBOSE $msg");
    return $msg;
}

=pod

=head2 debug

verbose logger, ignores debug level

=cut

sub debug
{
    my ($self, $level, @args) = @_;
    return $self->verbose(@args);
}


=pod

=head2 warn

warn-type logger, calls diag
Arguments are converted in message, prefixed with 'WARN'.

=cut

sub warn
{
    my ($self, @args) = @_;
    my $msg = join('', @args);
    diag("WARN: $msg");
    return $msg;
}

=pod

=head2 error

error-type logger, calls diag
Arguments are converted in message, prefixed with 'ERROR'.

=cut

sub error
{
    my ($self, @args) = @_;
    my $msg = join('', @args);
    diag("ERROR: $msg");
    return $msg;
}

=pod

=head2 notok

Fail a test with message, use error to log the message.
Arguments are converted in message.

=cut

sub notok
{
    my ($self, @args) = @_;
    my $msg = $self->error(@args);
    ok(0, $msg);
}

=pod 

=head2 gather_pan

Walk the C<panpath> and gather all pan templates.

A pan template is a text file with an C<.pan> extension; 
they are considered 'invalid' when the C<pannamespace> is not 
correct.

Returns a reference to hash with key path 
(relative to C<relpath>) and value hashreference
with 'type' of pan templates and 'expected' relative filepath;
and an arrayreference to the invalid pan templates.

=cut

sub gather_pan
{
    my ($self, $relpath, $panpath, $pannamespace) = @_;
    ok(-d $relpath, "relpath $relpath exists and is directory");
    ok(-d $panpath, "panpath $panpath exists and is directory");

    # sanitize the namespace
    $pannamespace =~ s/\/+/\//g;
    $pannamespace =~ s/\/$//;

    # add trailing / to pannamespace if not-empty
    $pannamespace .= '/' if $pannamespace;

    my (%pans, @invalid_pans);

    my $namespacereg = qr{^(declaration|unique|object|structure)\stemplate\s$pannamespace(\S+);$};
    $self->verbose("Namespace regex pattern $namespacereg");

    my $wanted = sub {
        my $name = $File::Find::name;
        $name =~ s/^$relpath\/+//;

        # relative to namespace
        my $panrel = dirname($File::Find::name);
        $panrel =~ s/^$panpath\/*//;
        $panrel .= '/' if $panrel;    # add trailing / here

        if (-T && m/(.*)\.(pan)$/) {
            my $tplname = basename($1);

            my $expectedname = "$panrel$tplname";

            # must match template namespace
            open(TPL, $_);
            my $value = {};
            while (my $line = <TPL>) {
                chomp($line);         # no newline in regexp
                if ($line =~ m/$namespacereg/) {
                    if ($2 eq $expectedname) {
                        $self->verbose("Found matching template $2 type $1");
                        $value = {type => $1, expected => "$pannamespace$expectedname.pan"};
                    } else {
                        $self->verbose(
                            "Found mismatch template $2 type $1 with expected name $expectedname");
                    }
                }
            }
            close(TPL);
            if ($value->{type}) {
                $pans{$name} = $value;
            } else {
                $self->verbose("Found invalid template $name (expectedname $expectedname)");
                push(@invalid_pans, $name);
            }
        }
    };

    find($wanted, $panpath);

    return \%pans, \@invalid_pans;
}

1;
