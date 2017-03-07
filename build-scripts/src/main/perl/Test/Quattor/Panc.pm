# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

package Test::Quattor::Panc;

use strict;
use warnings;

use base 'Exporter';

use Test::More;
use Readonly;

use CAF::Process;
use Test::MockModule;
use Test::Quattor::Object;

use Cwd;
use Carp qw(carp croak);
use File::Path qw(mkpath);
use Cwd qw(getcwd);

our @EXPORT = qw(panc panc_annotations is_object_template
                 set_panc_options reset_panc_options get_panc_options
                 set_panc_includepath get_panc_includepath);

Readonly my $PANC_MINIMAL => '10.2';


# A Test::Quattor::Object instance, can be used as logger.
my $object = Test::Quattor::Object->new();

=pod

=head1 DESCRIPTION

Module to compile profiles using panc

=cut

my (%pancoptions);

=pod

=head2 set_panc_options

Set additional panc commandline options.
Use the long option name, the preceding '--' is added.
If no value is expected (e.g. '--debug') pass 'undef' as value.

=cut

sub set_panc_options
{
    my (%options) = @_;
    while (my ($option, $value) = each %options) {
        $pancoptions{$option} = $value;
    }
}


=pod

=head2 reset_panc_options

Reset the panc commandline options.

=cut

sub reset_panc_options
{
    %pancoptions = ();
}

=pod

head2 get_panc_options

Returns the hash reference to the additional pancoptions.

=cut

sub get_panc_options
{
    return \%pancoptions;
}

=pod

=head2 set_panc_includepath

Set the inlcudedirs option to the directories passed.
If undef is passed, remove the 'includepath' option.

=cut

sub set_panc_includepath
{
    my (@dirs) = @_;

    if (@dirs) {
        $pancoptions{"include-path"} = join(':', @dirs);
    } else {
        delete $pancoptions{"include-path"};
    }

}

=pod

=head2 get_panc_includepath

Return an array reference with the 'includepath' directories.

=cut

sub get_panc_includepath
{
    if (exists($pancoptions{"include-path"})) {
        my @dirs = split(':', $pancoptions{"include-path"});
        return \@dirs;
    } else {
        return [];
    }
}


=pod

=head2 is_object_template

Given profile name (and optional resourcesdir for relative profile filename),
test if the profile is a valid object template.

=cut

sub is_object_template
{
    my ($profile, $resourcesdir) = @_;

    $profile .= ".pan" if ($profile !~ m/\.pan$/ );
    $profile = "$resourcesdir/$profile" if $resourcesdir && $profile !~ m/^\//;

    if (! -f $profile) {
        $object->error("Profile $profile does not exist.");
        return;
    };

    my $ok;
    open(my $TPL, '<', $profile) or croak("is_object_template failed to open $profile: $!");
    my $annotation;
    while (my $line = <$TPL>) {
        chomp($line);
        next if ($line =~ m/^\s*($|#)/); # ignore whitespace/comments
        if ($line =~ m/^\s*@\w*\{/ || $annotation) {
            $annotation = $line !~ m/\}\s*$/;
        } else {
            $ok = $line =~ m/^\s*object\s*template/;
            last;
        };
    };
    close($TPL);

    if (! $ok) {
        $object->error("Profile $profile is not valid object template");
    };
    return $ok;
}

=pod

=head2 Compile pan object template into JSON profile

Compile the pan C<profile> (file 'C<profile>.pan' in C<resourcesdir>)
and create the profile in C<outputdir>.

If C<croak_on_error> is true (or undef), the method croaks on compilation failure.
If false, it will return the exitcode.

=cut

sub panc
{

    my ($profile, $resourcesdir, $outputdir, $croak_on_error) = @_;

    $croak_on_error = 1 if (! defined($croak_on_error));

    my $currentdir = getcwd();
    $outputdir = "$currentdir/$outputdir" if ($outputdir !~ m/^\//);

    if( ! -d $outputdir) {
        mkpath($outputdir)
            or croak("Couldn't create output directory $outputdir");
    }

    chdir($resourcesdir) or croak("Couldn't enter resources directory $resourcesdir");

    my @panccmd = qw(panc --formats json --output-dir);
    push(@panccmd, $outputdir);
    foreach my $option (sort keys %pancoptions) {
        push(@panccmd, "--$option");
        # support options like --debug with no value
        my $value = $pancoptions{$option};
        push(@panccmd, $value) if (defined($value));
    }
    $profile .= ".pan" if ($profile !~ m/\.pan$/ );
    push(@panccmd, $profile);

    my $pancmsg = "Pan compiler called from directory $resourcesdir";
    return process(\@panccmd, $pancmsg, croak_on_error => $croak_on_error, srcdir => $currentdir);
}

=pod

=head2 panc_annotations

Generate the pan annotations from C<basedir> in C<outputdir> for C<profiles>.

=cut

sub panc_annotations
{

    my ($basedir, $outputdir, $profiles) = @_;

    if( ! -d $outputdir) {
        mkpath($outputdir)
            or croak("Couldn't create output directory $outputdir");
    }

    my $panccmd = ["panc-annotations",
                   "--base-dir", $basedir,
                   "--output-dir", $outputdir,
                   "-v", # verbose
                  ];
    push(@$panccmd, @$profiles);

    my $pancmsg = "Pan annotations called";
    return process($panccmd, $pancmsg, output => 1);
}

=pod

=head2 process

Sort-of private method to use C<CAF::Process> bypassing the mocking of C<CAF::Process>.

Arrayhash C<$cmd> for the command, C<$message> for a message to print.

Options

=over

=item croak_on_error: C<croak> on error

=item srcdir: srcdir to return to after actual command is executed.

=item output: return arrayref with exitcode and output (stdout combined with stderr)

=back

=cut

sub process
{

    my ($cmd, $message, %opts) = @_;

    my $output;
    # Test::MockModule keeps the currently mocked modules in a local hash,
    # and will return a previously existing one.
    my $mock = Test::MockModule->new('CAF::Process');

    my $proc = CAF::Process->new($cmd, stdout => \$output, stderr => 'stdout');

    # avoid possible mocking, call original method if needed
    if($mock->is_mocked("execute")) {
        my $execute = $mock->original("execute");
        $execute->($proc);
    } else {
        $proc->execute();
    };

    chdir($opts{srcdir}) if defined($opts{srcdir});

    if ($?) {
        my $msg = "Process failed. Minimal panc version is $PANC_MINIMAL. ";
        $msg .= "$message (proc $proc) with output\n$output";
        if($opts{croak_on_error}) {
            croak($msg);
        } else {
            $object->info($msg);
        }
    } else {
        $object->debug("$message (proc $proc)");
    }

    if ($opts{output}) {
        return [$?, $output];
    } else {
        return $?;
    };
};


1;
