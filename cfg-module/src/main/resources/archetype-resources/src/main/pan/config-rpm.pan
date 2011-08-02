# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

unique template components/${artifactId}/config-rpm;

include { 'components/${artifactId}/config-common' };

# Set prefix to root of component configuration.
prefix '/software/components/${artifactId}';

# Install Quattor configuration module via RPM package.
'/software/packages' = pkg_repl('ncm-${artifactId}','${no-snapshot-version}-${RELEASE}','noarch');
'dependencies/pre' ?= list('spma');

