package simple_caf;

# A simple module to test mocked CAF functionality
#  CAF::Path

use Readonly;

use CAF::Object qw(SUCCESS);
use CAF::FileWriter;
use parent qw(CAF::Object CAF::Path);

Readonly our $EXISTS => 123;

sub _initialize
{
    my ($self, %opts) = @_;

    $self->{log} = $opts{log} if $opts{log};

    return SUCCESS;
}

# make a file with content text
# if file already exists, return $EXISTS
sub make_file
{
    my ($self, $filename, $text) = @_;
    if ($self->file_exists($filename)) {
        return $EXISTS;
    } else {
        my $fh = CAF::FileWriter->new($filename);
        print $fh $text;
        $fh->close();
        return SUCCESS;
    }
}

# make a directory
# if directory already exists, return $EXISTS
sub make_directory
{
    my ($self, $dir) = @_;
    if ($self->directory_exists($dir)) {
        return $EXISTS;
    } else {
        $self->directory($dir);
        return SUCCESS;
    }
}


1;
