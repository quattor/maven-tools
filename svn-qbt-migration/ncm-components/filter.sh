#!/bin/bash -x

if [ -z "$2" ]
then
  MAKEQBT="make -j3 BTDIR=$HOME/quattor/ncm-components/quattor-build-tools"
else
  MAKEQBT="make -j3 BTDIR=$2"
fi

trap "exit 1" ERR

$MAKEQBT
# All files may not exist in all revisions...
perl_files=$(find . -maxdepth 1 -name '*.pod' -or -name '*.pm')
tpl_files=$(find TPL -name '*.tpl')
for file in ${perl_files} ${tpl_files}
do
  sed -i '1,12c\
# ${license-info}\
# ${developer-info}\
# ${author-info}\
# ${build-info}\
#' $file
done

cp -r ../../../$1 ncm-$1
if [ -n "${perl_files}" ]
then
  mv ${perl_files} ncm-$1/src/main/perl/ || exit 1
fi
for tpl in ${tpl_files}
do
  tplname=$(echo $tpl | awk -F/ '{print $NF}' | sed -e 's/\.tpl$//')
  tplnew=${tplname}.pan
  if [ "$tplname" != "config" ]
  then
    mv $tpl ncm-$1/src/main/pan/components/$1/${tplnew} || exit 1
    if [ "$tplname" != "schema" ]
    then
      sed -i -e "/include/ainclude { 'components/\${project.artifactId}/$tplname' };" ncm-$1/src/main/pan/components/$1/config-common.pan
    else
      # Fix obsolete syntax for include and bind in some components
      sed -i -e "s/include *quattor\/schema/include { 'quattor\/schema' }/" ncm-$1/src/main/pan/components/$1/schema.pan
      sed -i -e "s/include *pan\/types/include { 'pan\/types' }/" ncm-$1/src/main/pan/components/$1/schema.pan
      sed -i -e "s/^type *component_$1/type \${project.artifactId}_component/" \
             -e "s/= *component_$1/= \${project.artifactId}_component/" \
             -e "s/: *component_$1/: \${project.artifactId}_component/" \
             -e "s/include *component_$1/include \${project.artifactId}_component/" \
             -e "s/\? *component_$1/\? \${project.artifactId}_component/" ncm-$1/src/main/pan/components/$1/schema.pan
      sed -i -e "/^type *[\"']\/software\/components/cbind '\/software\/components\/\${project.artifactId}' = \${project.artifactId}_component;" ncm-$1/src/main/pan/components/$1/schema.pan
    fi
  fi
done
if [ -d DATA ]
then
  [ -d ncm-$1/src/main/templates ] || mkdir ncm-$1/src/main/templates || exit 1
  mv DATA/* ncm-$1/src/main/templates
fi
$MAKEQBT clean
v=`grep VERSION config.mk|cut -d= -f2`
git rm --ignore-unmatch -rf ChangeLog *.cin Makefile DEPENDENCIES INSTALL TPL DATA \
    MAINTAINER CERN-CC conf doc specfile.spec LICENSE config.mk README CHANGES
sed -i '{
N
/<\/packaging>\n\s*<version>/c\  <packaging>pom</packaging>\n  <version>_COMP_VERSION_</version>
}' ncm-$1/pom.xml 
sed -i "s/_COMP_VERSION_/$v-SNAPSHOT/" ncm-$1/pom.xml
git add ncm-$1
