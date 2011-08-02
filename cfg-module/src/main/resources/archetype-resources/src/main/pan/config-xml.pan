# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

unique template components/${artifactId}/config-xml;

include { 'components/${artifactId}/config-common' };

# Set prefix to root of component configuration.
prefix '/software/components/${artifactId}';

# Embed the Quattor configuration module into XML profile.
'code' = file_contents('components/${artifactId}/${artifactId}.pm'); 
