object template configelement;

# This is a bad example, don't base any actual code on it.
# Typically, there is only one config which has the correct
# settings for that service. This configelement is only to test
# the element settings

include 'metaconfig/testservice/config';

prefix "/software/components/metaconfig/services/{/test/file}";
"element/doublequote" = true;

prefix "/software/components/metaconfig/services/{/test/file}/contents";
"data" = "default";
"extra" = "more";

