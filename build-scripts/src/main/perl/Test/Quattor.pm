# -*- mode: cperl -*-

=pod

=head1 SYNOPSIS

    use Test::Quattor qw(test_profile1 test_profile2...);

=head1 DESCRIPTION

C<Test::Quattor>

Module preparing the environment for testing Quattor code.

=head1 LOADING

When loading this module it will compile any profiles given as arguments. So,

    use Test::Quattor qw(foo);

will trigger a compilation of C<src/test/resources/foo.pan> and the
creation of a binary cache for it. The compiled profile will be stored
as C<target/test/profiles/foo.json>, while the cache will be stored in
under C<target/test/profiles/foo/>.

This binary cache may be converted in an
L<EDG::WP4::CCM::Configuration> object using the
C<get_config_for_profile> function.

=head1 INTERNAL INFRASTRUCTURE

=head2 Module variables

This module provides backup methods for several C<CAF> modules. They
will prevent tests from actually modifying the state of the system,
while allowing an NCM component to follow a realistic execution path.

These backups record what files are being written, what commands are
being run, and allow for inspection by a test.

This is done with several functions, see B<Redefined functions> below,
that control the following variables:

=cut

package Test::Quattor;

use strict;
use warnings;
use CAF::FileWriter;
use CAF::Process;
use CAF::FileEditor;
use CAF::Application;
use IO::String;
use base 'Exporter';
use Cwd;
use Carp qw(carp croak);
use File::Path qw(mkpath);
use Test::MockModule;
use Test::More;
use CAF::Service;
use Test::Quattor::ProfileCache qw(prepare_profile_cache get_config_for_profile);

=pod

=over

=item * C<$log_cmd>

A boolean to enable logging of each command that is run via CAF::Process.
Can also be set via the QUATTOR_TEST_LOG_CMD environment variable.

=cut

our $log_cmd = $ENV{QUATTOR_TEST_LOG_CMD};

=pod

=item * C<$log_cmd_missing>

A boolean to log each cmd that has output mocked but has no output set.
Can also be set via the QUATTOR_TEST_LOG_CMD_MISSING environment variable.

=cut

our $log_cmd_missing = $ENV{QUATTOR_TEST_LOG_CMD_MISSING};


=pod

=item * C<%files_contents>

Contents of a file after it is closed. The keys of this hash are the
absolute paths to the files.

=cut

my %files_contents;

=pod

=item * C<%commands_run>

CAF::Process objects being associated to a command execution.

=cut

my %commands_run;

=pod

=item * C<%commands_status>

Desired exit status for a command. If the command is not present here,
it is assumed to succeed.

=cut

my %command_status;

=pod

=item * C<%desired_outputs>

When we know the component will call C<CAF::Process::output> and
friends, we prepare here an output that the component will have to
deal with.

=cut

my %desired_outputs;

=pod

=item * C<%desired_err>

When the component may analyse the standard error of a component, we
supply it through this hash.

=cut

my %desired_err;

=pod

=item * C<%desired_file_contents>

Optionally, initial contents for a file that should be "edited".

=cut

my %desired_file_contents;

=pod

=item * C<@command_history>

CAF::Process commands that were run.

=cut

my @command_history = ();

=pod

=item * C<caf_file_close_diff>

A boolean to mimick the regular (i.e. when no C<NoAction> is set) behaviour of a 
C<CAF::FileWriter> or C<CAF::FileEditor> C<close> (it returns wheter or not the 
file changed). With C<NoAction> set, this check is skipped and C<undef> is returned.

With this boolean set to true, contents difference is reported ( but not any chanegs 
due to e.g. file permissions or anything else checked with C<LC::Check::file)>.

Defaults to false (to keep regular C<NoAction> behaviour).

=cut

my $caf_file_close_diff = 0;


our @EXPORT = qw(get_command set_file_contents get_file set_desired_output
                 set_desired_err get_config_for_profile set_command_status
                 command_history_reset command_history_ok set_service_variant
                 set_caf_file_close_diff);

$main::this_app = CAF::Application->new('a', "--verbose", @ARGV);

# Modules that will have some methods mocked. These must be globals,
# or the test script and component will see the original, unmocked
# versions.
our $procs = Test::MockModule->new("CAF::Process");
our $filewriter = Test::MockModule->new("CAF::FileWriter");
our $fileeditor = Test::MockModule->new("CAF::FileEditor");
our $iostring = Test::MockModule->new("IO::String");

sub import
{
    my $class = shift;

    foreach my $pf (@_) {
        prepare_profile_cache($pf);
    }

    $class->SUPER::export_to_level(1, $class, @EXPORT);
}

=pod

=back

=head2 Redefined functions

In order to achieve this, the following functions are redefined
automatically:

=over

=item C<CAF::Process::{run,execute,output,trun,toutput}>

Prevent any command from being executed.

=cut


foreach my $method (qw(run execute trun)) {
    $procs->mock($method, sub {
                    my $self = shift;
                    my $cmd = join(" ", @{$self->{COMMAND}});
                    push(@command_history, $cmd);
                    diag("$method command $cmd") if $log_cmd;
                    $commands_run{$cmd} = { object => $self,
                                            method => $method
                                          };
                    if (exists($command_status{$cmd})) {
                        $? = $command_status{$cmd};
                    } else {
                        $? = 0;
                    }
                    if ($self->{OPTIONS}->{stdout}) {
                        ${$self->{OPTIONS}->{stdout}} = $desired_outputs{$cmd};
                    }
                    if ($self->{OPTIONS}->{stderr}) {
                        my $tmp_stderr = $desired_err{$cmd};
                        if (ref($self->{OPTIONS}->{stderr})) {
                            ${$self->{OPTIONS}->{stderr}} = $tmp_stderr;
                        } else {
                            ${$self->{OPTIONS}->{stdout}} .= $tmp_stderr if $tmp_stderr;
                        }
                    }
                    return 1;
                });
}

foreach my $method (qw(output toutput)) {
    $procs->mock($method, sub {
                    my $self = shift;

                    my $cmd = join(" ", @{$self->{COMMAND}});
                    push(@command_history, $cmd);
                    diag("$method command $cmd") if $log_cmd;
                            $commands_run{$cmd} = { object => $self,
                                                    method => $method};
                            $? = $command_status{$cmd} || 0;
                    if (exists($desired_outputs{$cmd})) {
                        return $desired_outputs{$cmd};
                    } else {
                        diag("$method no desired output for cmd $cmd") if $log_cmd_missing;
                        return ""; # always return something, like LC:Process does
                    };
                });
}

=pod

=item C<CAF::FileWriter::open>

Overriding this function allows us to inspect its contents after the
unit under tests has released it.

=cut

my $old_open = \&CAF::FileWriter::new;
my $old_close = \&CAF::FileWriter::close;

sub new_filewriter_open
{
    my $f = $old_open->(@_);

    my $fn = *$f->{filename};
    delete $files_contents{$fn};
    $files_contents{$fn} = $f;

    $files_contents{*$f->{filename}} = $f;
    return $f;
}

sub new_filewriter_close
{
    my ($self, @rest) = @_;

    my $ret;
    my $current_content = $desired_file_contents{*$self->{filename}};
    my $new_content = $self->stringify;

    # keep the save value here, since save is forced to 0 in old_close with NoAction set
    my $save = *$self->{save};

    if ($self->noAction()) {
        $self->cancel();
    }
    
    $desired_file_contents{*$self->{filename}} =  $new_content if $save;
    $ret = $old_close->(@_);

    if ($caf_file_close_diff && $save) {
        $ret = (! defined($current_content)) || $current_content ne $new_content;
    }
    
    return $ret;
}

$filewriter->mock("open", \&new_filewriter_open);
$filewriter->mock("new", \&new_filewriter_open);
$filewriter->mock("close", \&new_filewriter_close);


=pod

=item C<CAF::FileEditor::new>

It's just calling CAF::FileWriter::new, plus initialising its contnts
with the value of the appropriate entry in C<%desired_file_contents>

=cut


sub new_fileeditor_open
{

    my $f = CAF::FileWriter::new(@_);
    $f->set_contents($desired_file_contents{*$f->{filename}});
    return $f;
}

$fileeditor->mock("new", \&new_fileeditor_open);
$fileeditor->mock("open", \&new_fileeditor_open);

=pod

=item C<IO::String::close>

Prevents the buffers from being released when explicitly closing a file.

=back

=cut


$iostring->mock("close", undef);


=pod

=head1 FUNCTIONS FOR EXTERNAL USE

The following functions are exported by default:

=over

=item C<get_file>

Returns the object that has manipulated C<$filename>

=cut


sub get_file
{
    my ($filename) = @_;

    if (exists($files_contents{$filename})) {
        return $files_contents{$filename};
    }
    return undef;
}


=pod

=item C<set_file_contents>

For file C<$filename>, sets the initial C<$contents> the component shuold see.

=cut


sub set_file_contents
{
    my ($filename, $contents) = @_;

    $desired_file_contents{$filename} = $contents;
}


=pod

=item C<get_command>

Returns all the information recorded about the execution of C<$cmd>,
if it has been executed. This is a hash reference in which the
C<object> element is the C<CAF::Process> object itself, and the
C<method> element is the function that executed the command.

=cut


sub get_command
{
    my ($cmd) = @_;

    if (exists($commands_run{$cmd})) {
        return $commands_run{$cmd};
    }
    return undef;
}

=pod

=item C<set_command_status>

Sets the "exit status" we'll report for a given command.

=cut

sub set_command_status
{
    my ($cmd, $st) = @_;

    $command_status{$cmd} = $st;
}

=pod

=item C<set_desired_output>

Sets the standard output we'll return when the caller issues C<output>
on this command

=cut

sub set_desired_output
{
    my ($cmd, $out) = @_;

    $desired_outputs{$cmd} = $out;
}

=pod

=item C<set_desired_err>

Sets the standard error we'll receive when the caller issues
C<execute> on this command.

=cut

sub set_desired_err
{
    my ($cmd, $err) = @_;

    $desired_err{$cmd} = $err;
}

=pod

=item C<command_history_reset>

Reset the command history to empty list.

=cut

sub command_history_reset
{
    @command_history = ();
}

=pod

=item C<command_history_ok>

Given a list of commands, it checks the C<@command_history> if all commands were
called in the given order (it allows for other commands to exist inbetween).
The commands are interpreted as regular expressions.

E.g. if C<@command_history> is (x1, x2, x3) then
C<command_history_ok([x1,X3])> returns 1 (Both x1 and x3 were called and in that order,
the fact that x2 was also called but not checked is allowed.).
C<command_history_ok([x3,x2])> returns 0 (wrong order),
C<command_history_ok([x1,x4])> returns 0 (no x4 command).

=cut

sub command_history_ok
{
    my $commands = shift;

    my $lastidx = -1;
    foreach my $cmd (@$commands) {
        # start iterating from lastidx+1
        my ( $index )= grep { $command_history[$_] =~ /$cmd/  } ($lastidx+1)..$#command_history;
        return 0 if !defined($index) or $index <= $lastidx;
        $lastidx = $index;
    };
    # in principle, when you get here, all is ok.
    # but at least 1 command should be found, so lastidx should be > -1
    return $lastidx > -1;
}

=pod

=item C<set_service_variant>

Sets the C<CAF::Service> variant to the one given in the command line:

=over

=item * C<linux_sysv>

Linux SysV, e.g, C</sbin/service foo start>

=item * C<linux_systemd>

Linux, Systemd variant.

=item * C<solaris>

Solaris and SMF variant.

=back

It defaults to C<linux_sysv>.

=cut

sub set_service_variant
{
    my $variant = shift;

    # More methods will be added as we agree on them in the
    # CAF::Service API.
    foreach my $method (qw(start stop restart create_process)) {
        no strict 'refs';
        if (CAF::Service->can("${method}_$variant")) {
            *{"CAF::Service::$method"} =
                *{"CAF::Service::${method}_$variant"};
        } else {
            croak "Unsupported variant $variant";
        }
    }
}

set_service_variant("linux_sysv");

=pod

=item C<set_caf_file_close_diff>

Set the C<caf_file_close_diff> boolean.

=cut

sub set_caf_file_close_diff
{
    my $state = shift;
    $caf_file_close_diff = $state ? 1 :0;
};

1;

__END__

=pod

=back

=head1 BUGS

Probably many. It does quite a lot of internal black magic to make
your executions safe. Please ensure your component doesn't try to
outsmart the C<CAF> library and everything should be fine.

=cut
