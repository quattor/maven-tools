${BUILD_INFO}
${LEGAL}

unique template components/@COMP@/config;

include { 'components/@COMP@/schema' };

# Package to install
'/software/packages' = pkg_repl('@NAME@','@VERSION@-@RELEASE@','noarch');
'/software/components/@COMP@/dependencies/pre' ?= list('spma');

'/software/components/@COMP@/version' = '@VERSION@';
 
'/software/components/@COMP@/active' ?= true;
'/software/components/@COMP@/dispatch' ?= true;
