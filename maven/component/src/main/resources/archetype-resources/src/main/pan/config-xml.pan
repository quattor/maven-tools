# ${BUILD_INFO}
# ${LEGAL}

unique template components/${quattor.component}/config-xml;

include { 'components/${quattor.component}/config-common' };

# Set prefix to root of component configuration.
prefix '/software/components/${quattor.component}';

# Embed the Quattor configuration module into XML profile.
'code' = file('components/${quattor.component}/${quattor.component}.pm'); 
