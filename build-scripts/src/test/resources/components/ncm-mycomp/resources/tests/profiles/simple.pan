object template simple;

include 'components/mycomp/schema';

# TT relpath is mycomp
# use /metaconfig as default for Test::Quattor::RegexpTest
"/metaconfig/module" = "main";

prefix "/metaconfig/contents";
"data" = "default_simple";
"extra" = "more_simple";
