${BUILD_INFO}
${LEGAL}

package ${quattor.package}::${quattor.component};

use strict;
use warnings;

use base qw(${quattor.parent});

use LC::Exception;
use LC::Find;
use LC::File qw(copy makedir);

use EDG::WP4::CCM::Element;
use CAF::FileWriter;
use CAF::FileEditor;
use CAF::Process;
use File::Basename;
use File::Path;

use Readonly;
Readonly::Scalar my $PATH => '/software/components/${quattor.component}';

our $EC=LC::Exception::Context->new->will_store_all;

# Restart the process.
sub restartDaemon {
    my ($self) = @_;
    CAF::Process->new([qw(/etc/init.d/example restart)], log => $self)->run();
    return;
}

sub Configure {
    my ($self, $config) = @_;

    # Get full tree of configuration information for component.
    my $t = $config->getElement($PATH)->getTree();

    # Create the configuration file.

    # Restart the daemon if necessary.

}

1; # Required for perl module!
