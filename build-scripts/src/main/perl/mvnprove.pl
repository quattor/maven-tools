#!/usr/bin/perl

use warnings;
use strict;

use Readonly;
use Data::Dumper;

use File::Path qw(mkpath rmtree);
use File::Find ();
use XML::Simple qw(:strict);

use App::Prove;

use Cwd;

Readonly my $POM_XML => 'pom.xml';
Readonly my $MAX_ITER => 2;


=head1 Description

Run the unittests without maven.

Set the internal debug level with MVNPROVE_DEBUG environment variable (See debug function). 

Prove settings can be added via the C<~/.mvnprove> (instead of C<~/.proverc>)

=cut

my $debug = defined($ENV{MVNPROVE_DEBUG}) ? $ENV{MVNPROVE_DEBUG} : -1;

# For templating
my $properties;

=head2 Functions

=over

=item error

print ERROR message and die

=cut

sub error
{
    print "ERROR: @_\n";
    die "$@";
}

=item info

Print INFO message

=cut

sub info
{
    print "INFO: @_\n";
}

=item debug

Print DEBUG message if first argument debuglevel is lower or equal than the
debug (Set to -1 by default, changeable via C<MVNPROVE_DEBUG> environment variable).

=cut

sub debug
{
    my $level = shift;
    print "DEBUG: @_\n" if $debug >= $level;
}

=item filter_source

Search and replace C<text> with properties.
If C<$iter> is set, perform this C<iter> times.

(If iter is undef, MAX_ITER is assumed).

=cut

sub filter_source
{
    my ($text, $iter) = @_;

    $iter = $MAX_ITER if(!defined($iter));
    debug(1, "Filter source with iter $iter");

    # Sorted for reproducability
    foreach my $prop (sort keys %$properties) {
        $text =~ s/$prop/$properties->{$prop}/g;
    };

    $text = filter_source($text, $iter -1) if ($iter);

    return $text;
}

=item read_pom

Readin pom file and extract relevant data

=over

=item defaults from maven-tools/build-profile

=item build-phase details from maven-resources-plugin build plugin

=item build-phase details from profiles build plugin

=back

=cut

sub read_pom
{
    my $pom = XMLin($POM_XML, ForceArray => [qw(profile plugin execution)], KeyAttr => [], KeepRoot => 1);
    debug(3, "Read $POM_XML", Dumper($pom));

    # Defaults from maven-tools/build-profile
    my $directories = {
        'filter-pan-sources' => {
            'outputDirectory' => '${project.build.directory}/pan/',
            'sources' => 'src/main/pan',
        },
        'filter-perl-sources' => {
            'outputDirectory' => '${project.build.directory}/lib/perl/NCM/Component',
            'sources' => 'src/main/perl',
        },
        'filter-pod-sources' => {
            'outputDirectory' => '${project.build.directory}/doc/pod/NCM/Component',
            'sources' => 'src/main/perl',
        },
    };


    my $data = {
        directories => $directories,
        version => $pom->{project}->{version},
        artifactId  => $pom->{project}->{artifactId},
    };

    my @plugins;
    my $project_build = $pom->{project}->{build}->{plugins}->{plugin} || [];
    push(@plugins, @{$project_build});

    my $profiles = $pom->{project}->{profiles}->{profile} || [];
    debug(4, "Profiles from $POM_XML", Dumper($profiles));
    foreach my $prof (@$profiles) {
        my $prof_plugins = $prof->{build}->{plugins}->{plugin} || [];
        debug(4, "Profile from $POM_XML", Dumper($prof), Dumper($prof_plugins));
        push(@plugins, @$prof_plugins);
    };

    debug(4, "Build plugins from $POM_XML", Dumper(\@plugins));


    foreach my $plugin (@plugins) {
        if ($plugin->{artifactId} eq "maven-resources-plugin") {
            foreach my $exe (@{$plugin->{executions}->{execution}}) {
                if($exe->{phase} eq 'process-sources') {
                    debug(4, "Execution from $POM_XML", Dumper($exe));

                    $data->{directories}->{$exe->{id}} = {
                        outputDirectory => $exe->{configuration}->{outputDirectory},
                        sources => $exe->{configuration}->{resources}->{resource}->{directory},
                    };
                }
            }
        }
    };

    debug(1, "Return data from $POM_XML ", Dumper($data));
    return $data;
}

=item set_properties

Set the propeties to use when filtering the sources

=cut

sub set_properties
{
    my $pom = shift;

    my $fullversion = $pom->{version} || '0.0.0-NOVERSIONFOUND';
    my ($version, $snapshot) = split(/-/, $fullversion);
    my $props = {
        'project.artifactId' => $pom->{artifactId} || 'NoArtifactFound',
        'project.version' => $fullversion,
        'no-snapshot-version' => $version,
        'rpm.release' => $snapshot,
        # from build-profile
        RELEASE => $snapshot,
        PMpost => "\n\nuse strict;\nuse warnings;\n\nuse version;\nour \$VERSION = version->new(\"v$version\");\n\n",
        'project.build.directory' => 'target',
        PMPre => "\# Some headers\n\npackage", # headers are not relevant
        basedir => getcwd(), #
    };

    foreach my $prop (sort keys %$props) {
        $prop =~ s/\./\./g;
        my $pattern = '\$\{'.$prop.'\}';
        $properties->{qr{$pattern}} = $props->{$prop};
    };

    # Run the properties through filtersource twice
    foreach my $iter (qw(1..2)) {
        foreach my $prop (sort keys %$properties) {
            $properties->{$prop} = filter_source($properties->{$prop});
        }
    }

    debug(1, "properties", Dumper($properties))
}


=item prep

Cleanup and make new project.build.directory, and all outputdirectories
found via read_pom.

=cut

sub prep
{
    my $pom = shift;
    my $target = filter_source('${project.build.directory}');
    if (-d $target) {
        debug(2, "Removing existing target dir $target");
        rmtree($target);
    }
    foreach my $id (sort keys %{$pom->{directories}}) {
        my $path = $pom->{directories}->{$id}->{outputDirectory};
        debug(2, "mkpath $path");
        mkpath($path);
    };
}


=item process

Read all files under C<src>, filter them and write them out in C<dst>.

=cut

sub process
{
    my ($src_dir, $dst_dir) = @_;

    debug(1, "process src $src_dir dst $dst_dir");
    my $wanted = sub {
        my $dir = $File::Find::dir;
        my $fn = $File::Find::name;

        return if (! -f $fn);

        my $rel_dir = $dir;
        $rel_dir =~ s{^$src_dir}{};

        my $rel_fn = $fn;
        $rel_fn =~ s{^$src_dir}{};

        debug(2, "Process wanted $fn (rel $rel_fn)");
        mkpath("$dst_dir/$rel_dir") if (! -d "$dst_dir/$rel_dir");

        open(my $src, $fn) || die("Failed to open source file $fn: $!");
        open(my $dst, "> $dst_dir/$rel_fn") || die ("Failed to open destination file $dst_dir/$rel_fn: $!");
        print $dst filter_source(join('', <$src>));
        close($dst);
        close($src);
        debug(2, "Wrote $dst_dir/$rel_fn");
    };

    File::Find::find({wanted => \&$wanted, no_chdir => 1}, $src_dir);
}

=item prove

Run prove

=cut

sub prove
{
    my ($pom, @test_names) = @_;

    # -v : verbose
    # ignore default proverc, use mvnprove
    my @args = qw(-v --norc --rc ~/.mvnprove);

    my $tests_dir = 'src/test/perl';

    # Are added to beginning of INC and the order is kept
    # (first entry here will be first in @INC)
    my @includes = (
        filter_source('${project.build.directory}/lib/perl'),
        $tests_dir,

        # This has to be last, should not take precedence over the code we are testing
        '/usr/lib/perl',
        );

    foreach my $inc (@includes) {
        push(@args, '-I', $inc);
    }

    if (@test_names) {
        foreach my $test_name (@test_names) {
            push(@args, "$tests_dir/$test_name.t");
        };
    } else {
        # --state: run all tests, last failed first
        push(@args, '--state=failed,all,save', $tests_dir);
    }

    debug(1, "Going to run prove with args @args");

    my $app = App::Prove->new;
    $app->process_args(@args);

    my $ec = $app->run ? 0 : 1;
    if($ec) {
        error("Prove failed");
    } else {
        info("Prove ok");
    };
    return $ec;
}

sub main
{
    my $pom = read_pom();

    set_properties($pom);

    # Filter some pom variables
    foreach my $id (sort keys %{$pom->{directories}}) {
        my $dir = $pom->{directories}->{$id};
        $dir->{outputDirectory} = filter_source($dir->{outputDirectory});
        $dir->{sources} = filter_source($dir->{sources});
    };

    debug(1, "Filter_source data from $POM_XML ", Dumper($pom));

    prep($pom);

    foreach my $id (sort keys %{$pom->{directories}}) {
        my $dir = $pom->{directories}->{$id};
        debug(1, "Processing id $id");
        process($dir->{sources}, $dir->{outputDirectory});
    };

    my $ec = prove($pom, @ARGV);

    exit($ec);
};


main();


=pod

=back

=cut
