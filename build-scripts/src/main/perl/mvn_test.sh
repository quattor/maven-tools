#
# Wrapper functions for running unittests with maven.
# Typical usage is to source this file and run mvn_test.
#
# Variables:
#    QUATTOR_PERL5LIB: PERL5LIB to use; defaults to /usr/lib/perl
#    QUATTOR_TEST_LOG_DEBUGLEVEL: run unittests with this debug level (default is 3)
#    MVN_ARGS: additional arguments to pass to the mvn call
#
# Functions:
#    mvn_test: run "mvn clean test", optional argument is the name of the perl unittest (without .t)
#        supports tabcompletion
#    mvn_pack: run "mvn clean package", to create packages

export QUATTOR_PERL5LIB=${QUATTOR_PERL5LIB:-/usr/lib/perl}

function mvn_run()
{
    local unsetfn quatenv
    quatenv="PERL5LIB=$QUATTOR_PERL5LIB QUATTOR_TEST_LOG_CMD_MISSING=1 QUATTOR_TEST_LOG_CMD=1"
    quatenv="$quatenv QUATTOR_TEST_LOG_DEBUGLEVEL=${QUATTOR_TEST_LOG_DEBUGLEVEL:-3}"

    # make a subshell with all bashfunctions removed. maven can have issues with them
    #   via exporting with env.BASH_FUNC
    unsetfn=""
    for fn in $(env |grep BASH_FUNC_ | grep -v grep | sed "s/(.*//; s/BASH_FUNC_//" |tr "\n" ' '); do
        unsetfn="unset -f $fn; $unsetfn"
    done
    bash -c "$unsetfn $quatenv mvn $1"
}

function mvn_test()
{
    local extra
    if [ ! -z "$1" ]; then
       extra="-Dunittest=$1.t"
    fi
    mvn_run "clean test -Dprove.args=-v $extra $MVN_ARGS"
}

function mvn_pack()
{
    mvn_run "clean package -Dprove.args=-v $MVN_ARGS"
}

function _mvn_test_complete()
{
    local search
    search="src/test/perl/${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -f $search | grep -E '\.t$' | sed 's#^src/test/perl/##;s/\.t$//' ) )
}

complete -F _mvn_test_complete mvn_test
export -f mvn_run
export -f mvn_test
export -f mvn_pack
