# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

unique template components/example/config-common;

include { 'components/example/schema' };

# Set prefix to root of component configuration.
prefix '/software/components/example';

'version' = '${version}';
'package' = '${quattor.package}';

'active' ?= true;
'dispatch' ?= true;
