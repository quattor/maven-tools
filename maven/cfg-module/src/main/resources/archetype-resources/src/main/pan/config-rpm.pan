# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

unique template components/example/config-rpm;

include { 'components/example/config-common' };

# Set prefix to root of component configuration.
prefix '/software/components/example';

# Install Quattor configuration module via RPM package.
'/software/packages' = pkg_repl('ncm-example','${version}-1','noarch');
'dependencies/pre' ?= list('spma');

