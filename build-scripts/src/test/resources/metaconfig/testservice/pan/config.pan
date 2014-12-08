unique template metaconfig/testservice/config;

include 'metaconfig/testservice/schema';

bind "/software/components/metaconfig/services/{/test/file}/contents" = testservice_config;

prefix "/software/components/metaconfig/services/{/test/file}";
"module" = "testservice/1.0/main";
