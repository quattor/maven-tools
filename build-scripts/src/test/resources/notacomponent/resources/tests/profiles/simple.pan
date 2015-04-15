object template simple;

# Make sure it's different from the other simple.pan files in same test
"/unique" = 1;

# TT relpath is mycomp
# use /metaconfig as default for Test::Quattor::RegexpTest
"/metaconfig/module" = "main";

prefix "/metaconfig/contents";
"data" = "default_simple";
"extra" = "more_simple";
