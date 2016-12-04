package Test::Quattor::Filetools;

use strict;
use warnings;

use parent qw(Exporter);
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use Readonly;

our @EXPORT_OK = qw(readfile writefile);

Readonly our $DEFAULT_CONTENT => "ok";

=pod

=head1 NAME

Test::Quattor::Filetools - Read/write files
(in case mocked FileWriter/Reader cannot be used).

=head1 Functions

=over

=item writefile

Create file with name C<fn> (and parent directory if needed).
Optional second argument is the
content of the file (default is text C<ok> (no newline)).

=cut

sub writefile
{
    my $fn = shift;
    my $dir = dirname($fn);
    mkpath $dir if ! -d $dir;
    open(my $fh, '>', $fn) or die "Filetools writefile failed to open $fn: $!";
    print $fh (shift || $DEFAULT_CONTENT);
    close($fh) or die "Filetools writefile failed to close $fn: $!";
}

=item readfile

Read the content of file C<fn> and return it.

=cut

sub readfile
{
    my $fn = shift;
    open(my $fh, $fn) or die "Filetools readfile failed to open $fn: $!";
    my $txt = join('', <$fh>);
    close($fh) or die "Filetools readfile failed to close $fn: $!";

    return $txt;
}

=pod

=back

=cut

1;
