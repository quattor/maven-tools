BEGIN {
our $TQU = <<'EOF';
[load]
prefix=Test::Quattor::
# Do NOT list Unittest here, it will cause an infinite loop
# Unittest is tested elsewhere
modules=:,CommonDeps,Component,Doc,Namespace,Object,Panc,ProfileCache,RegexpTest,TextRender,TextRender,TextRender::Base,TextRender::Component,TextRender::Metaconfig,TextRender::RegexpTest,TextRender::Suite
EOF
    }
use Test::Quattor::Unittest;
