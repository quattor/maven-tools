#!/bin/bash

module="$1"
version="$2"
description="$3"
developer="$4"
email="$5"

if [ -n "$6" ]
then
  mvncmd=$6
else
  mvncmd=mvn
fi
echo "Using Maven command '${mvncmd}'"

${mvncmd} archetype:generate \
    -DarchetypeArtifactId=cfg-module \
    -DarchetypeGroupId=org.quattor.maven \
    -DarchetypeVersion=1.29 \
    -DartifactId="$module" \
    -Dversion="$version-SNAPSHOT" \
    -Dpackage="components/$module" \
    -Ddescription="$description" \
    -Ddeveloper="$developer" \
    -Ddeveloper-email="$email" \
    -B

# Add necessary resources to generated pom.xml if the component
# has some template configuration files (in DATA directory)
if [ -d ncm-${module}/DATA ]
then
  echo "Adding support for template configuration files in pom.xml"
  sed -i -e '/<plugins>/r pom.templates_dir' ${module}/pom.xml 
fi
