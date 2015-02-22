unique template metaconfig/nottservice/config;

include 'metaconfig/nottservice/schema';

bind "/software/components/metaconfig/services/{/test/nottfile}/contents" = nottservice_config;

prefix "/software/components/metaconfig/services/{/test/nottfile}";
"module" = "yaml";
