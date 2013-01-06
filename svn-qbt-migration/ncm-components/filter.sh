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
if [ -d DATA ]
then
  [ -d ncm-$1/src/main/templates ] || mkdir ncm-$1/src/main/templates || exit 1
  mv DATA/* ncm-$1/src/main/templates
fi
$MAKEQBT clean
v=`grep VERSION config.mk|cut -d= -f2`
git rm --ignore-unmatch -rf ChangeLog *.cin Makefile DEPENDENCIES INSTALL TPL DATA \
    MAINTAINER CERN-CC conf doc specfile.spec LICENSE config.mk README CHANGES
#sed -i "s/$2/$v/" ncm-$1/pom.xml
git add ncm-$1
