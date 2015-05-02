object template nopan;

# simple template that requires no pan

"/metaconfig2/module" = "testservice/1.0/main";

prefix "/metaconfig2/contents";
"data" = "default_simple";
"extra" = "more_simple";

prefix "/override/contents";
"data" = "default_override";
"extra" = "more_override";
