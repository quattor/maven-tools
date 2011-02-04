# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

unique template components/example/config-xml;

include { 'components/example/config-common' };

# Set prefix to root of component configuration.
prefix '/software/components/example';

# Embed the Quattor configuration module into XML profile.
'code' = file('components/example/example.pm'); 
