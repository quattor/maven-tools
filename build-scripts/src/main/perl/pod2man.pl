#!/usr/bin/perl -w
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;
use File::Path qw(mkpath);
use File::Find ();
use Pod::Man;

# for the convenience of &wanted calls, including -eval statements:
use vars qw/*name *dir *prune/;
*name   = *File::Find::name;
*dir    = *File::Find::dir;
*prune  = *File::Find::prune;

sub wanted;

our $release = shift || die "must supply release number\n";

# Traverse desired filesystems
File::Find::find({wanted => \&wanted, no_chdir => 1}, 'target/lib/perl');

exit;

sub extract_module_name {
    my ($name) = @_;

    if ($name =~ m{([^/]+)\.pod\z$}) {
        return $1;
    }

    my $pkg_name = undef;

    open(my $fh, '<', $name) || die "error opening $name: $!\n";

    while (<$fh>) {
        if (/package\s+(.*?)\s*;/sx) {
            $pkg_name = $1;
            last;
        }
    }

    close($fh) || die "error closing $name: $!\n";

    if (!defined($pkg_name)) {
        die "package not found for module $name\n";
    }

    return $pkg_name;
}


sub extract_pod_name {
    my ($name) = @_;

    my $orig = $name;

    $name =~ s!\.pm!\.pod!gx;
    $name =~ s!/lib/perl/!/doc/pod/!x;

    # again, look for pod file. if it finds it, use it.
    # if the pod file can't be found, try the original one.
    $name = $orig if (! -f $name);

    return $name;
}


sub create_man_page {
    my ($pod_fname, $module_name, $section) = @_;

    my $parser = Pod::Man->new(release => $release, section => $section);

    print "Creating man page for $pod_fname, $module_name.$section";
    my $odir = "target/doc/man/man$section";
    mkpath($odir);

    my $ofile = "$odir/$module_name.8";
    my $gzfile = "$ofile.gz";

    $parser->parse_from_file($pod_fname, $ofile);

    # This uses the commandline rather than IO::Compress::Gzip because that
    # module is not installed by default on current RHEL releases.  Delete
    # existing file before compression.
    if (-e $gzfile) {
        unlink $gzfile;
    }
    `gzip $ofile`;

    return;
}


sub process_perl_module {
    my ($name) = @_;

    print "Generating man page from $name\n";
    
    my $module_name = eval{extract_module_name($name);} || return;
    my $pod_name = extract_pod_name($name);
    create_man_page($pod_name, $module_name, 8);

    return;
}

sub is_perl_file {
    my ($file) = @_;

    return 0 if (! -f $file);

    if ($file =~ /^(.*)\.p([ml]|od)\z/sx) {
        # if .pod exists of this file, ignore this one (the pod will be used)
        return 0 if ($2 ne 'od' && -f "$1.pod");

        return 1;
    }

    # If we don't know the file name, it may still be a Perl
    # script. Check the shebang.
    open(my $fh, "<", $file);
    my $head = <$fh>;
    close($fh);
    return ($head && $head =~ m{^#!/usr/bin/perl});
}

sub wanted {
    is_perl_file($name) && process_perl_module($name);
    return;
}

