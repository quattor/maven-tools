BEGIN {
    our $TQU = <<'EOF';
[load]
prefix=Test::Quattor::
# Do NOT list Unittest here, it will cause an infinite loop
# Unittest is tested elsewhere
modules=:,CommonDeps,Component,Critic,Doc,Filetools,Namespace,Object,Panc,ProfileCache,RegexpTest,TextRender,TextRender,TextRender::Base,TextRender::Component,TextRender::Metaconfig,TextRender::RegexpTest,TextRender::Suite,Tidy
[doc]
poddirs=src/main/perl
panpaths=NOPAN
[critic]
codedirs=src/main/perl
# there is not ${PMpost} templating in maven-tools
exclude=Modules::RequireVersionVar
[tidy]
codedirs=src/main/perl
EOF
    }
use Test::Quattor::Unittest;
