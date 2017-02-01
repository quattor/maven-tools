# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

package Test::Quattor::Critic;

use strict;
use warnings;

BEGIN {
    # Insert the Policy::Critic::Policy::Quattor namespace
    use Test::Quattor::Namespace qw(critic);
}

use Test::Pod;
use File::Temp qw(tempfile);
use Perl::Critic 1.118;
use Perl::Critic::Violation;
use Readonly;
use Test::More;

use parent qw(Test::Quattor::Object);

# Do not report violations of the blacklisted policies
# Precedes whitelist and severity
Readonly::Array my @BLACKLIST_POLICIES => qw(
);

# Report all violations of these policies
Readonly::Array my @WHITELIST_POLICIES => qw(
    InputOutput::ProhibitBarewordFileHandles
    InputOutput::ProhibitBacktickOperators
    Modules::RequireEndWithOne
    Modules::RequireExplicitPackage
    Modules::RequireVersionVar
    TestingAndDebugging::RequireUseWarnings
);

# Report all violations that have higher or equal severity
Readonly my $SEVERITY => 5;

# Policy configuration
Readonly::Hash my %POLICIES => {
    'TestingAndDebugging::ProhibitNoStrict' => {
        allow => 'refs', # space separated list
    }
};


# work around annoying Critic bug https://github.com/Perl-Critic/Perl-Critic/pull/711
use Perl::Critic::Policy::Modules::RequireVersionVar;
no warnings 'redefine';
*Perl::Critic::Policy::Modules::RequireVersionVar::prepare_to_scan_document = sub {
    my ( $self, $document ) = @_;
    return $document->is_module();   # Must be a library or module.
};
use warnings 'redefine';

=pod

=head1 NAME

Test::Quattor::Critic - Run Perl::Critic.

=head1 DESCRIPTION

This is a class to run Perl::Critic code with a whitelist of policies.

To get the policy names, use
    critic --cruel --verbose 8 path/to/perl/code

=head1 METHODS

=over

=item new

=over

=item codedirs

An arrayref of paths to look for perl code (uses C<Test::Pod::all_pod_files>).

Default is C<target/lib/perl>.

=item exclude

A regexp to remove policies from list of fatal policies.

=back

=cut

sub _initialize
{
    my $self = shift;
    $self->{codedirs} = [qw(target/lib/perl)] if ! $self->{codedirs};

    # Don't pass these for now.
    # But can be used for unittesting
    $self->{whitelist} = \@WHITELIST_POLICIES if (! defined($self->{whitelist}));
    $self->{blacklist} = \@BLACKLIST_POLICIES if (! defined($self->{blacklist}));
    $self->{severity} = $SEVERITY if (! defined($self->{severity}));
    $self->{policies} = {%POLICIES} if (! defined($self->{policies}));

    # exclude filter
    $self->{whitelist} = [grep {$_ !~ /$self->{exclude}/} @{$self->{whitelist}}] if $self->{exclude};
    $self->{blacklist} = [grep {$_ !~ /$self->{exclude}/} @{$self->{blacklist}}] if $self->{exclude};
}

=item make_critic

Create C<Perl::Critic> instance and load policies

=cut

sub make_critic
{
    my $self = shift;

    my ($fh, $filename) = tempfile('critic_empty_profile.XXXXX', UNLINK => 1);
    foreach my $policy (sort keys %{$self->{policies}}) {
        print $fh "[$policy]\n";
        foreach my $key (sort keys %{$self->{policies}->{$policy}}) {
            print $fh "$key = ".$self->{policies}->{$policy}->{$key}."\n";
        }
    }
    $fh->flush();

    my $critic = Perl::Critic->new(
        -verbose => 8, # Use verbose level 8 to show the name of the policy
        -profile => $filename, # contains all policy configuration
        -severity => 1, # all policies
        );


    #my @active_policies = $critic->policies();
    #$self->debug(1, "critic policies: @active_policies");

    # Readable format
    Perl::Critic::Violation::set_format("%f %s %p %m L%l C%c %e");

    return $critic;
}

=item check

Given a list of C<Perl::Critic::Violations> (e.g. as return value of
C<critique> method) and check which one should be reported on.

=cut

sub check
{
    my ($self, $violations) = @_;

    my ($wl_pattern, $bl_pattern);
    $wl_pattern = '('.join('|', @{$self->{whitelist}}).')$'  if @{$self->{whitelist}};;
    $bl_pattern = '('.join('|', @{$self->{blacklist}}).')$' if @{$self->{blacklist}};;;

    my @reported;

    foreach my $v (@$violations) {
        # Don't check/report multiple times
        next if grep {$_ eq "$v"} @reported;

        if ($bl_pattern && $v->policy() =~ m/$bl_pattern/) {
            $self->verbose("Ignore blacklisted violation $v");
        } elsif ($v->severity() >= $self->{severity}) {
            $self->notok("Failed policy violation $v (severity)");
        } elsif ($wl_pattern && $v->policy() =~ m/$wl_pattern/) {
            $self->notok("Failed policy violation $v (whitelist)");
        } else {
            # Last one, report for future consideration
            $self->verbose("Ignore violation $v");
        }
        push(@reported, "$v");
    }
}

=item test

Run critic test on all files found with C<all_pod_files> in all codedirs.

=cut

sub test
{
    my $self = shift;

    my $critic = $self->make_critic();

    foreach my $dir (@{$self->{codedirs}}) {
        $self->notok("codedir $dir is not a directory") if ! -d $dir;
        my @fs = all_pod_files($dir);

        if (@fs) {
            foreach my $file (@fs) {
                next if ($file =~ m/\.pod$/);
                my @violations = $critic->critique($file);
                $self->check(\@violations);
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
