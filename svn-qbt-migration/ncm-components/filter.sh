#!/bin/bash -x

if [ -z "$2" ]
then
  MAKEQBT="make -j3 BTDIR=$HOME/quattor/ncm-components/quattor-build-tools"
else
  MAKEQBT="make -j3 BTDIR=$2"
fi

$MAKEQBT
sed -i '1,12c\
# ${license-info}\
# ${developer-info\
# ${author-info}\
# ${build-info}\
#' *.pm

cp -r ../../../$1 ncm-$1
ls -p
mv *pm ncm-$1/src/main/perl/ || exit 1
$MAKEQBT clean
v=`grep VERSION config.mk|cut -d= -f2`
git rm --ignore-unmatch -rf ChangeLog *.cin Makefile DEPENDENCIES INSTALL TPL \
    MAINTAINER CERN-CC conf doc specfile.spec LICENSE config.mk README CHANGES
#sed -i "s/$2/$v/" ncm-$1/pom.xml
git add ncm-$1
