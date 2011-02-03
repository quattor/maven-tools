# ${BUILD_INFO}
# ${LEGAL}

unique template components/${quattor.component}/config-rpm;

include { 'components/${quattor.component}/config-common' };

# Set prefix to root of component configuration.
prefix '/software/components/${quattor.component}';

# Install Quattor configuration module via RPM package.
'/software/packages' = pkg_repl('ncm-${quattor.component}','${version}-1','noarch');
'dependencies/pre' ?= list('spma');

