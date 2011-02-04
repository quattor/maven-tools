# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

unique template components/${artifactId}/config-common;

include { 'components/${artifactId}/schema' };

# Set prefix to root of component configuration.
prefix '/software/components/${artifactId}';

'version' = '${version}';
'package' = 'NCM::Component';

'active' ?= true;
'dispatch' ?= true;
