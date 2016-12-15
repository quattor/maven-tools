# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

package Test::Quattor::Critic;

use strict;
use warnings;

use Test::Pod;
use File::Temp qw(tempfile);
use Perl::Critic;
use Perl::Critic::Violation;
use Readonly;
use Test::More;

use parent qw(Test::Quattor::Object);

# Load these and test for these
Readonly::Array my @DEFAULT_POLICIES => qw(
    InputOutput::ProhibitBarewordFileHandles
    Modules::RequireEndWithOne
    Modules::RequireExplicitPackage
    Modules::RequireVersionVar
    TestingAndDebugging::RequireUseStrict
    TestingAndDebugging::RequireUseWarnings
    Subroutines::ProhibitExplicitReturnUndef
);


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
    $self->{policies} = \@DEFAULT_POLICIES if (! defined($self->{policies}));
    # exclude filter
    $self->{policies} = [grep {$_ !~ /$self->{exclude}/} @{$self->{policies}}] if $self->{exclude};

}

=item make_critic

Create C<Perl::Critic> instance and load policies

=cut

sub make_critic
{
    my $self = shift;

    my ($fh, $filename) = tempfile('critic_empty_profile.XXXXX', UNLINK => 1);
    my $critic = Perl::Critic->new(
        -verbose => 8, # Use verbose level 8 to show the name of the policy
        -profile => $filename, # empty temporary file, i.e. don't load any profile
        -severity => 1, # all policies
        );

    foreach my $policy (@{$self->{policies}}) {
        $critic->add_policy(-policy => $policy);
    }

    #my @active_policies = $critic->policies();
    #$self->debug(1, "critic policies: @active_policies");

    # Readable format
    Perl::Critic::Violation::set_format("%f %p %m L%l C%c %e");

    return $critic;
}

=item check

Given a list of C<Perl::Critic::Violations> (e.g. as return value of
C<critique> method) and check which one should be reported on.

=cut

sub check
{
    my ($self, $violations) = @_;

    my $policy_pattern = '('.join('|', @{$self->{policies}}).')$';

    my @reported;

    foreach my $v (@$violations) {
        # Don't check/report multiple times
        next if grep {$_ eq "$v"} @reported;

        if ($v->policy() =~ m/$policy_pattern/) {
            $self->notok("Failed policy violation $v");
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
