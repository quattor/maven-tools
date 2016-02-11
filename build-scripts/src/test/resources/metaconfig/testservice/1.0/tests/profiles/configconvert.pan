object template configconvert;

# This is a bad example, don't base any actual code on it.
# Typically, there is only one config which has the correct
# settings for that service. This configconvert is only to test
# the convert settings

include 'metaconfig/testservice/config';

prefix "/software/components/metaconfig/services/{/test/file}";
"convert/doublequote" = true;

prefix "/software/components/metaconfig/services/{/test/file}/contents";
"data" = "default";
"extra" = "more";

