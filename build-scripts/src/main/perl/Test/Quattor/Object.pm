# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;

package Test::Quattor::Object;

use base 'Exporter';

our @ISA;
use Test::More;

use File::Basename;
use File::Find;
use Cwd qw(abs_path getcwd);
use File::Path qw(mkpath);

use Readonly;

# Old Test::More on EL5
if(! defined &note) {
    no warnings 'redefine';
    sub note { diag(@_) }
};


# The target pan directory used by maven to stage the
# to-be-distributed pan templates
Readonly our $TARGET_PAN_RELPATH => 'target/pan';

our @EXPORT = qw($TARGET_PAN_RELPATH);

# Keep track of all logged messages
my $loghist = {};

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

=head2 add_loghist

Add a log C<message> for C<type> to the log history.

=cut

sub loghist_add
{
    my ($self, $type, $message) = @_;

    $self->{LOGCOUNT}->{$type}++;
    $self->{LOGLATEST}->{$type} = $message;
    push(@{$loghist->{$type}}, $message);
}

=pod

=head2 reset_loghist

Reset the log history.

=cut

sub loghist_reset
{
    my ($self) = @_;
    $self->{LOGCOUNT} = {};
    $self->{LOGLATEST} = {};
    $loghist = {};
}

=pod

=head2 loghist_get

Return the array of log messages for C<type>.

=cut

sub loghist_get
{
    my($self, $type) = @_;
    return defined($loghist->{$type}) ? @{$loghist->{$type}} : undef;
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
    $self->loghist_add('INFO', $msg);
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
    $self->loghist_add('VERBOSE', $msg);
    note("VERBOSE $msg");
    return $msg;
}

=pod

=head2 report

report-type logger, calls note
Arguments are converted in message, prefixed with 'REPORT'.

=cut

sub report
{
    my ($self, @args) = @_;
    my $msg = join('', @args);
    $self->loghist_add('REPORT', $msg);
    note("REPORT $msg");
    return $msg;
}

=pod

=head2 debug

verbose logger, ignores debug level

=cut

sub debug
{
    my ($self, $level, @args) = @_;
    my $msg = join('', @args);

    if (! $level =~/^[12345]$/ ) {
        ok(0, "debug logging with unsupported level $level message $msg");
    }

    $self->loghist_add('DEBUG', "$level $msg");
    note("DEBUG: $level $msg");
    return $msg;
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
    $self->loghist_add('WARN', $msg);
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
    $self->loghist_add('ERROR', $msg);
    diag("ERROR: $msg");
    return $msg;
}

=head2 event

event handler, store the metadata and report added event

=cut

sub event
{
    my ($self, $obj, %metadata) = @_;

    # We cannot keep any references to objects alive, e.g. during DESTROY
    my $ref = ref($obj);

    $metadata{_objref} = $ref;

    $self->loghist_add('EVENT', \%metadata);

    diag("EVENT: added $ref ".join(',', map {"$_=".(defined($metadata{$_}) ? $metadata{$_} : '<undef>')} sort keys %metadata));

    return \%metadata;
}


=head2 is_verbose / is_quiet / get_debuglevel

Return the respective attributes (or 0 is undefined).

=cut

sub is_verbose
{
    my $self = shift;
    return $self->{is_verbose} || 0;
}

sub is_quiet
{
    my $self = shift;
    return $self->{is_quiet} || 0;
}

sub get_debuglevel
{
    my $self = shift;
    return $self->{get_debuglevel} || 0;
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

    find({
        wanted => $wanted,
        preprocess => sub { return sort { $a cmp $b } @_ },
    }, $panpath);

    return \%pans, \@invalid_pans;
}

=pod

=head2 get_template_library_core

Return path to C<template-library-core> to allow "include 'pan/types';"
and friends being used in the templates (in particular the schema).

By default, the C<template-library-core> is expected to be in the
parent or parent of parent directory as the current working directory.

One can also specify the location via the C<QUATTOR_TEST_TEMPLATE_LIBRARY_CORE>
environment variable.

When C<notok_on_missing> is true (or undefined), C<notok> is called (i.e. test fails).

=cut

sub get_template_library_core
{
    # only for logging
    my ($self, $notok_on_missing) = @_;

    $notok_on_missing = 1 if (! defined($notok_on_missing));

    my $tlc = $ENV{QUATTOR_TEST_TEMPLATE_LIBRARY_CORE};
    if ($tlc) {
        my $msg = "template-library-core path $tlc set via QUATTOR_TEST_TEMPLATE_LIBRARY_CORE";
        if (-d $tlc) {
            $self->verbose($msg);
        } else {
            # Log it
            $self->info("$msg, but it is not a directory.");
            $tlc = undef;
        }
    } else {

        # TODO: better guess?
        my $d = "../template-library-core";
        if (-d $d) {
            $tlc = $d;
        } elsif (-d "../$d") {
            $tlc = "../$d";
        } else {
            $self->error("no more guesses for template-library-core path: tlc ",
                         $tlc ? $tlc : "");
            # Force it undef
            $tlc = undef;
        }
    }
    if ($tlc) {
        $tlc = abs_path($tlc);
        $self->verbose("template-library-core path found $tlc");
    } else {
        my $msg = "No template-library-core path found (set QUATTOR_TEST_TEMPLATE_LIBRARY_CORE?)";
        if($notok_on_missing) {
            $self->notok($msg);
        } else {
            $self->info($msg);
        }
    }
    return $tlc;
}

=pod

=head2 make_target_pan_path

Create if needed the "target/pan" path in the current directory, and returns the
absolute pathname.

=cut

sub make_target_pan_path
{
    my $self = shift;

    # Always add the TARGET_PAN_RELPATH to the includepath of the compilation
    my $dest = getcwd() . "/$TARGET_PAN_RELPATH";
    if (!-d $dest) {
        mkpath($dest)
    }

    return $dest;
}

1;
