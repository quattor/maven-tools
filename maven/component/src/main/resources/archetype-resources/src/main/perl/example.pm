${BUILD_INFO}
${LEGAL}

package NCM::Component::@COMP@;

use strict;
use warnings;

use NCM::Component;

use LC::Exception;
use LC::Find;
use LC::File qw(copy makedir);

use EDG::WP4::CCM::Element;
use CAF::FileWriter;
use CAF::FileEditor;
use CAF::Process;
use File::Basename;
use File::Path;

# Base class for a Quattor component.
use base qw(NCM::Component);

use Readonly;
Readonly::Scalar my $PATH => '/software/components/@COMP@';

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
