# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

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
C<EDG::WP4::CCM::CacheManager::Configuration> object using the
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

BEGIN {
    # Insert the NCM:: namespace
    use Test::Quattor::Namespace qw(ncm);
}

use CAF::FileWriter;
use CAF::Process;
use CAF::FileEditor;
use CAF::Application;
use CAF::Path;
use CAF::Object qw(SUCCESS);
use IO::String;
use base 'Exporter';
use Cwd;
use Carp qw(carp croak);
use File::Path qw(mkpath);
use File::Basename;
use Test::MockModule;
use Test::More;
use CAF::Service qw(@FLAVOURS);
use Test::Quattor::ProfileCache qw(prepare_profile_cache get_config_for_profile);
use Test::Quattor::Object qw(warn_is_ok);
use Readonly;

# "File" content that will appear as a directory
Readonly our $DIRECTORY => 'MAGIC STRING, THIS IS A MOCKED DIRECTORY';

=over

=item * QUATTOR_TEST_LOG_DEBUGLEVEL

If the environment variable QUATTOR_TEST_LOG_DEBUGLEVEL is set, the unittests
will run with this debuglevel (0-5). Otherwise the default loglevel is 'verbose'.

To actually see the verbose or debug output, you need to run prove with verbose flag
(e.g. by passing C<-Dprove.args=-v> or by setting C<-v> in the C<<~/.proverc>>).

=item * C<$log_cmd>

A boolean to enable logging of each command that is run via CAF::Process.
Can also be set via the QUATTOR_TEST_LOG_CMD environment variable.

=cut

our $log_cmd = $ENV{QUATTOR_TEST_LOG_CMD};

=item * C<$log_cmd_missing>

A boolean to log each cmd that has output mocked but has no output set.
Can also be set via the QUATTOR_TEST_LOG_CMD_MISSING environment variable.

=cut

our $log_cmd_missing = $ENV{QUATTOR_TEST_LOG_CMD_MISSING};


=item * C<%files_contents>

Contents of a file after it is closed. The keys of this hash are the
absolute paths to the files.

=cut

our %files_contents;

=item * C<%commands_run>

CAF::Process objects being associated to a command execution.

=cut

our %commands_run;

=item * C<%commands_status>

Desired exit status for a command. If the command is not present here,
it is assumed to succeed.

=cut

our %command_status;

=item * C<%desired_outputs>

When we know the component will call C<CAF::Process::output> and
friends, we prepare here an output that the component will have to
deal with.

=cut

our %desired_outputs;

=item * C<%desired_err>

When the component may analyse the standard error of a component, we
supply it through this hash.

=cut

our %desired_err;

=item * C<%desired_file_contents>

Optionally, initial contents for a file that should be "edited".

=cut

our %desired_file_contents;

=item * C<@command_history>

CAF::Process commands that were run.

=cut

our @command_history = ();

=item * C<caf_path>

A hashref with C<CAF::Path> methods and arrayref of reference of used arguments

=cut

our $caf_path = {};

=item * C<NoAction>

Set C<Test::Quattor::NoAction> to override C<CAF::Object::NoAction>
in any of the mocked C<Test::Quattor> methods (where relevant, e.g.
mocked FileWriter and FileEditor).

E.g. if you want to run tests with C<CAF::Object::NoAction> not set
(to test the behaviour of regular C<CAF::Object::NoAction>).

=cut

our $NoAction;

=item * C<caf_file_close_diff>

A boolean to mimic the regular (i.e. when no C<NoAction> is set) behaviour of a
C<CAF::FileWriter> or C<CAF::FileEditor> C<close> (it returns whether or not the
file changed). With C<NoAction> set, this check is skipped and C<undef> is returned.

With this boolean set to true, contents difference is reported ( but not any changes
due to e.g. file permissions or anything else checked with C<LC::Check::file)>.

Defaults to false (to keep regular C<NoAction> behaviour).

=cut

my $caf_file_close_diff = 0;


our @EXPORT = qw(get_command set_file_contents get_file set_desired_output
                 set_desired_err get_config_for_profile set_command_status
                 command_history_reset command_history_ok set_service_variant
                 set_caf_file_close_diff
                 make_directory remove_any reset_caf_path
                 warn_is_ok);

my @logopts = qw(--verbose);
my $debuglevel = $ENV{QUATTOR_TEST_LOG_DEBUGLEVEL};
if (defined($debuglevel)) {
  if ($debuglevel !~ m/^[0-5]$/) {
    $debuglevel = 0;
  }
  push(@logopts, '--debug', $debuglevel);
}
$main::this_app = CAF::Application->new('a', @logopts, @ARGV);
$main::this_app->verbose("Log options ", join(" ", @logopts));

# Modules that will have some methods mocked. These must be globals,
# or the test script and component will see the original, unmocked
# versions.
our $procs = Test::MockModule->new("CAF::Process");
our $filewriter = Test::MockModule->new("CAF::FileWriter");
our $fileeditor = Test::MockModule->new("CAF::FileEditor");
our $reporter = Test::MockModule->new("CAF::Reporter");
our $cpath = Test::MockModule->new("CAF::Path");
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
        $commands_run{$cmd} = {
            object => $self,
            method => $method,
        };

        if (exists($command_status{$cmd})) {
            $? = $command_status{$cmd};
        } else {
            diag("$method command $cmd no status set, using 0") if $log_cmd;
            $? = 0;
        }

        my ($tmp_stdout, $tmp_stderr);
        if (exists($desired_outputs{$cmd})) {
            $tmp_stdout = $desired_outputs{$cmd};
        } else {
            diag("$method command $cmd no desired stdout set, using empty string") if $log_cmd;
            $tmp_stdout = '';
        }

        if (exists($desired_err{$cmd})) {
            $tmp_stderr = $desired_err{$cmd};
        } else {
            diag("$method command $cmd no desired stderr set, using empty string") if $log_cmd;
            $tmp_stderr = '';
        }

        if ($self->{OPTIONS}->{stdout}) {
            ${$self->{OPTIONS}->{stdout}} = $tmp_stdout;
        }

        if ($self->{OPTIONS}->{stderr}) {
            if (ref($self->{OPTIONS}->{stderr})) {
                ${$self->{OPTIONS}->{stderr}} = $tmp_stderr;
            } else {
                ${$self->{OPTIONS}->{stdout}} .= $tmp_stderr if exists($desired_err{$cmd});
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
        $commands_run{$cmd} = {
            object => $self,
            method => $method,
        };
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

    if(defined($NoAction)) {
        *$f->{options}->{noaction} = $NoAction;
    }

    my $fn = *$f->{filename};
    if (is_directory($fn)) {
        diag("ERROR: Cannot new_filewriter_open: $fn is a directory");
    } elsif(make_directory(dirname($fn))) {
        delete $files_contents{$fn};
        $files_contents{$fn} = $f;
        *$f->{_mocked} = {
            iostring => $iostring,
            filewriter => $filewriter,
        };
    } else {
        diag("ERROR: new_filewriter_open: failed to create directory for file $fn");
    }

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

    if ($ret && defined($current_content) && defined(*$self->{options}->{backup})) {
        $desired_file_contents{*$self->{filename} . *$self->{options}->{backup}} =  $current_content;
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

    if(defined($NoAction)) {
        *$f->{options}->{noaction} = $NoAction;
    }

    my $fn = *$f->{filename};
    if (is_directory($fn)) {
        diag("ERROR: Cannot new_fileeditor_open: $fn is a directory");
    } elsif(make_directory(dirname($fn))) {
        $f->set_contents($desired_file_contents{$fn});
        *$f->{_mocked}->{fileeditor} = $fileeditor;
    } else {
        diag("ERROR: new_fileeditor_open: failed to create directory for file $fn");
    }
    return $f;
}

$fileeditor->mock("new", \&new_fileeditor_open);
$fileeditor->mock("open", \&new_fileeditor_open);

=pod

=item C<CAF::Reporter::debug>

Checks that each debug() call starts with a debuglevel between 0 and 5.

=cut

sub new_debug
{
    my ($self, $debuglvl, @args) = @_;

    # Do not turn every debug call in a test,
    # simply let a test fail hard if debuglvl is not valid
    if (! defined($debuglvl) || $debuglvl !~ m/^[0-5]$/) {
        ok(0, "Debug level is integer between 0 and 5: ".(defined($debuglvl) ? $debuglvl : "<undef>" ));
    };

    my $debug = $reporter->original("debug");
    return &$debug($self, $debuglvl, @args);
}

$reporter->mock("debug", \&new_debug);

=pod

=item C<CAF::Reporter::debug>

Checks that each debug() call starts with a debuglevel between 0 and 5.

=cut

sub new_report
{
    my ($self, @args) = @_;

    # Do not turn every report call in a test,
    # simply report error or let a test fail hard if undef is passed
    if (grep {! defined($_)} @args) {
        my @newargs = map {defined($_) ? $_ : '<undef>'} @args;
        ok(0, "One of the reported arguments contained an undef: @newargs");
    }

    my $report = $reporter->original("report");
    return &$report($self, @args);
}

$reporter->mock("report", \&new_report);

=pod

=item C<IO::String::close>

Prevents the buffers from being released when explicitly closing a file.

=cut


$iostring->mock("close", undef);

=item C<CAF::Path::file_exists>

Return the mocked C<is_file>

=cut

$cpath->mock("file_exists", sub {shift; return is_file(shift);});

=item C<CAF::Path::directory_exists>

Return the mocked C<is_directory>

=cut

$cpath->mock("directory_exists", sub {shift; return is_directory(shift);});

=item C<CAF::Path::any_exists>

Return the mocked C<is_any>

=cut

$cpath->mock("any_exists", sub {shift; return is_any(shift); });

=item C<CAF::Path::directory>

Return directory name unless mocked C<make_directory> or mocked C<LC_Check> fail.

(The C<temp> is ignored wrt creating the directory name).

=cut

$cpath->mock("directory", sub {
    my ($self, $directory, %opts) = @_;
    if (make_directory($directory)) {
        $directory = undef if ! $self->LC_Check("directory", [$directory], \%opts);
    } else {
        $directory = undef;
    }
    return $directory;
});

=item C<CAF::Path::LC_Check>

Store args in C<caf_path> using C<add_caf_path>.

=cut

$cpath->mock('LC_Check', sub{ shift; return add_caf_path(@_); });

=item C<CAF::Path::cleanup>

C<remove_any> and store args in C<caf_path> using C<add_caf_path>.

=cut

# use ref of copy of args (similar to what is passed to LC_Check)
$cpath->mock('cleanup', sub {
    my($self, $dest, $backup, %opts) = @_;
    my $newbackup = defined($backup) ? $backup : $self->{backup};
    remove_any($dest, $newbackup);
    return add_caf_path('cleanup', [$dest, $backup], \%opts);
});

=item C<CAF::Path::move>

C<remove_any> and store args in C<caf_path> using C<add_caf_path>.

=cut

# use ref of copy of args (similar to what is passed to LC_Check)
$cpath->mock('move', sub {
    my($self, $src, $dest, $backup, %opts) = @_;
    my $newbackup = defined($backup) ? $backup : $self->{backup};
    move($src, $dest, $newbackup);
    return add_caf_path('move', [$src, $dest, $backup], \%opts);
});

=back

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
        if (is_directory($filename)) {
            diag("ERROR: get_file: $filename is a directory");
        } else {
            return $files_contents{$filename};
        }
    }
    return;
}


=pod

=item C<set_file_contents>

For file C<$filename>, sets the initial C<$contents> the component shuold see.

=cut


sub set_file_contents
{
    my ($filename, $contents) = @_;

    if (is_directory($filename)) {
        diag("ERROR: Cannot set_file_contents: $filename is a directory");
    } elsif(make_directory(dirname($filename))) {
        $desired_file_contents{$filename} = "$contents";
        return $desired_file_contents{$filename};
    } else {
        diag("ERROR: Cannot set_file_contents: cannot create directory for $filename");
    }
    return;
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
    return;
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

Given an arrayref of C<required_commands>,
it checks the C<@command_history> if all commands were
called in the given order (it allows for other commands to exist inbetween).
The commands are interpreted as regular expressions.

E.g. if C<@command_history> is (x1, x2, x3) then
C<command_history_ok([x1,X3])> returns 1
(Both x1 and x3 were called and in that order,
the fact that x2 was also called but not checked is allowed.).
C<command_history_ok([x3,x2])> returns 0 (wrong order),
C<command_history_ok([x1,x4])> returns 0 (no x4 command).

A second arrayref of C<forbidden_commands> can be given,
and the C<@command_history> is then first checked that
none of those commands occured.
If you only want to check the non-occurence of commands,
pass an undef as the first argument
(and not an empty arrayref).

=cut

sub command_history_ok
{
    my ($required_commands, $forbidden_commands) = @_;

    if ($forbidden_commands) {
        foreach my $cmd (@$forbidden_commands) {
            if (grep {$_ =~ /$cmd/} @command_history) {
                diag "command_history_ok: forbidden command '$cmd' found in history; return false";
                return 0;
            };
        }
    }

    if (! defined($required_commands)) {
        if ($forbidden_commands) {
            # This is ok.
            diag "No required commands to test and forbidden commands check was ok.";
            return 1;
        } else {
            # Fatal
            ok(0, "command_history_ok: neither required nor forbidden commands arguments specified");
        }
    };

    my $lastidx = -1;
    foreach my $cmd (@$required_commands) {
        # start iterating from lastidx+1
        my ( $index )= grep { $command_history[$_] =~ /$cmd/  } ($lastidx+1)..$#command_history;
        my $msg = "command_history_ok command pattern '$cmd'";
        if (!defined($index)) {
            diag "$msg no match; return false" if $log_cmd;
            return 0;
        } else {
            $msg .= " index $index (full command $command_history[$index])";
            if ($index <= $lastidx) {
                diag "$msg <= lastindex $lastidx; return false" if $log_cmd;
                return 0;
            } else {
                diag "$msg; continue" if $log_cmd;
            }
        };
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

C<Test::Quattor> defaults to C<linux_sysv>.

=cut

sub set_service_variant
{
    my ($variant) = @_;

    if (grep {$_ eq $variant} @FLAVOURS) {
        no warnings 'redefine';
        *CAF::Service::os_flavour = sub { return $variant; };
    } else {
        die "set_service_variant unsupported variant $variant";
    }
}

set_service_variant("linux_sysv");

=item C<force_service_variant>

Force the variant by bypassing C<CAF::Service> C<AUTOLOAD> magic
and defining the methods
via glob assignments in the namespace.

The first argument is the C<$variant> to use.

When testing subclassed C<CAF::Service>,
the second (optional) argument is the subclass, followed by
all other arguments as additional non-standard actions.

=cut

sub force_service_variant
{
    my ($variant, $subclass, @extraservices) = @_;

    my @services = qw(create_process start stop restart reload);

    # More methods will be added as we agree on them in the
    # CAF::Service API.
    foreach my $method (@services) {
        next if grep {$_ eq $method} @extraservices;
        no strict 'refs';
        if (CAF::Service->can("${method}_$variant")) {
            *{"CAF::Service::$method"} =
                *{"CAF::Service::${method}_$variant"};
        } else {
            croak "Unsupported variant $variant";
        }
    }

    # Blindly assume that the namespace is usable.
    foreach my $method (@extraservices) {
        no strict 'refs';
        *{"$subclass::$method"} = *{"$subclass::${method}_$variant"};
    }
}


=pod

=item C<set_caf_file_close_diff>

Set the C<caf_file_close_diff> boolean.

=cut

sub set_caf_file_close_diff
{
    my $state = shift;
    $caf_file_close_diff = $state ? 1 :0;
};


=item sane_path

sanitize path by

=over

=item squash multiple '/' into one

=item remove all trailing '/'

=back

=cut

sub sane_path
{
    my $path = shift;

    $path =~ s/\/+/\//g;
    $path =~ s/\/+$// if $path !~ m/^\/+$/;

    return $path;
}

=item is_file

Test if given C<$path> is a mocked file

=cut

sub is_file
{
    my $path = sane_path(shift);

    my $f_c = exists($files_contents{$path}) &&
        (! defined($files_contents{$path}) || "$files_contents{$path}" ne $DIRECTORY);
    my $d_f_c  = exists($desired_file_contents{$path}) &&
        (! defined($desired_file_contents{$path}) || "$desired_file_contents{$path}" ne $DIRECTORY);

    return $f_c || $d_f_c;
}

=item is_directory

Test if given C<$path> is a mocked directory

=cut

sub is_directory
{
    my $path = sane_path(shift);

    my $f_c = exists($files_contents{$path}) &&
        $files_contents{$path} && "$files_contents{$path}" eq $DIRECTORY;
    my $d_f_c  = exists($desired_file_contents{$path}) &&
        $desired_file_contents{$path} && "$desired_file_contents{$path}" eq $DIRECTORY;

    return $f_c || $d_f_c;
}

=item is_any

Test if given C<path> is known (as file or directory or anything else)

=cut

sub is_any
{
    my $path = sane_path(shift);

    return exists($files_contents{$path}) || exists($desired_file_contents{$path});
}



=item make_directory

Add a directory to the mocked directories.
If C<rec> is true or undef, also add all underlying directories.

If directory already exists and is a directory, return SUCCESS (undef otherwise).

=cut

# Make / dir
make_directory('/', 0);

sub make_directory
{
    my ($path, $rec) = @_;

    $rec = 1 if ! defined($rec);

    $path = sane_path($path);

    if (is_file($path)) {
        diag("ERROR: cannot make_directory $path: is_file");
        return;
    } else {
        if ($rec) {
            my $tmppath = '';
            foreach my $p (split(/\/+/, $path)) {
                $tmppath = "$tmppath/$p";
                return if ! make_directory($tmppath, 0);
            }
        } else {
            $files_contents{$path} = $DIRECTORY;
        }
    }

    return SUCCESS;
}

=item remove_any

Recursive removal of a C<path> from the files_contents / desired_file_contents

=cut

sub remove_any
{
    my $path = shift;

    $path = sane_path($path);

    my $filter = sub {
        my $fs = shift;
        my $pattern = '^'.$path.'/';
        foreach my $p (grep {m/$pattern/} sort keys %$fs) {
            delete $fs->{$p};
        }
        delete $fs->{$path};
    };
    &$filter(\%files_contents);
    &$filter(\%desired_file_contents);

    return SUCCESS;
}

=item move

move C<src> to C<dest>. If C<backup> is defined and not empty string,
move C<dest> to backup (C<backup> is a suffix).

=cut

sub move
{
    my ($src, $dest, $backup) = @_;

    if (is_any($src)) {
        if (is_any($dest)) {
            if (defined($backup) && $backup ne '') {
                move($dest,$dest.$backup);
            }
            remove_any($dest);
        };
        # Move src to dest
        $files_contents{$dest} = delete $files_contents{$src};
        $desired_file_contents{$dest} = delete $desired_file_contents{$src};
    };
    return SUCCESS;
};

=item add_caf_path

Add array of arguments to C<caf_path> hashref using C<name>

=cut

sub add_caf_path
{
    my ($name, @args) = @_;

    $caf_path->{$name} = [] if ! defined($caf_path->{$name});

    # push a reference of a copy of the args
    push(@{$caf_path->{$name}}, [@args]);
}

=item reset_caf_path

Reset C<caf_path> ref. If C<name> is defined, only reset that cache.

=cut

sub reset_caf_path
{
    my ($name) = @_;

    if (defined($name)) {
        $caf_path->{$name} = [];
    } else {
        $caf_path = {};
    }

}

1;

__END__

=pod

=back

=head1 BUGS

Probably many. It does quite a lot of internal black magic to make
your executions safe. Please ensure your component doesn't try to
outsmart the C<CAF> library and everything should be fine.

=cut
