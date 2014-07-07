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

=over 4

=cut

package Test::Quattor;

use strict;
use warnings;
use CAF::FileWriter;
use CAF::Process;
use CAF::FileEditor;
use CAF::Application;
use IO::String;
use EDG::WP4::CCM::Configuration;
use EDG::WP4::CCM::CacheManager;
use EDG::WP4::CCM::Fetch;
use base 'Exporter';
use Cwd;
use Carp qw(carp croak);
use File::Path qw(mkpath);
use Test::MockModule;
use Test::More;
use CAF::Service;

=pod

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


my %configs;

our @EXPORT = qw(get_command set_file_contents get_file set_desired_output
                 set_desired_err get_config_for_profile set_command_status
                 command_history_reset command_history_ok set_service_variant);

$main::this_app = CAF::Application->new('a', "--verbose", @ARGV);

# Modules that will have some methods mocked. These must be globals,
# or the test script and component will see the original, unmocked
# versions.
our $procs = Test::MockModule->new("CAF::Process");
our $filewriter = Test::MockModule->new("CAF::FileWriter");
our $fileeditor = Test::MockModule->new("CAF::FileEditor");
our $iostring = Test::MockModule->new("IO::String");

# Prepares a cache for the profile given as an argument. This means
# compiling the profile, fetching it and saving the binary cache
# wherever the CCM configuration tells us.
sub prepare_profile_cache
{
    my ($profile) = @_;

    my $dir = getcwd();

    my $cache = "target/test/cache/$profile";
    mkpath($cache);

    my $fh = CAF::FileWriter->new("$cache/global.lock");
    print $fh "no\n";
    $fh->close();
    $fh = CAF::FileWriter->new("$cache/current.cid");
    print $fh "1\n";
    $fh->close();
    $fh = CAF::FileWriter->new("$cache/latest.cid");
    print $fh "1\n";

    my $d = getcwd();

    chdir("src/test/resources") or croak("Couldn't enter resources directory");

    system(qw(panc --formats json --output-dir ../../../target/test/profiles), "$profile.pan") == 0
        or croak("Unable to compile profile $profile");
    chdir($d);
    my $f = EDG::WP4::CCM::Fetch->new({
                                       FOREIGN => 0,
                                       CONFIG => 'src/test/resources/ccm.cfg',
                                       CACHE_ROOT => $cache,
                                       PROFILE_URL => "file://$dir/target/test/profiles/$profile.json",
                                       })
        or croak ("Couldn't create fetch object");
    $f->{CACHE_ROOT} = $cache;
    $f->fetchProfile() or croak "Unable to fetch profile $profile";

    my $cm =  EDG::WP4::CCM::CacheManager->new($cache);
    $configs{$profile} = $cm->getUnlockedConfiguration();
}


sub import
{
    my $class = shift;

    mkpath("target/test/profiles");
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
                        if (ref($self->{OPTIONS}->{stderr})) {
                            ${$self->{OPTIONS}->{stderr}} = $desired_err{$cmd};
                        } else {
                            ${$self->{OPTIONS}->{stdout}} .= $desired_err{$cmd};
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

sub new_filewriter_open
{
    my $f = $old_open->(@_);

    $files_contents{*$f->{filename}} = $f;
    return $f;
}

$filewriter->mock("open", \&new_filewriter_open);
$filewriter->mock("new", \&new_filewriter_open);


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

=item C<get_config_for_profile>

Returns a configuration object for the profile given as an
argument. The profile should be one of the arguments given to this
module when loading it.

=cut

sub get_config_for_profile
{
    my ($profile) = @_;

    return $configs{$profile};
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

=item * C<linux_solaris>

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

1;

__END__

=pod

=back

=head1 BUGS

Probably many. It does quite a lot of internal black magic to make
your executions safe. Please ensure your component doesn't try to
outsmart the C<CAF> library and everything should be fine.

=cut
