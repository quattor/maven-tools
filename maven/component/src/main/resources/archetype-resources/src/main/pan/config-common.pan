# ${BUILD_INFO}
# ${LEGAL}

unique template components/${quattor.component}/config-common;

include { 'components/${quattor.component}/schema' };

# Set prefix to root of component configuration.
prefix '/software/components/${quattor.component}';

'version' = '${version}';
'package' = '${quattor.package}';

'active' ?= true;
'dispatch' ?= true;
