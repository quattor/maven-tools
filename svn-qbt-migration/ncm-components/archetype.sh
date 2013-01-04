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
    -DarchetypeVersion=1.27 \
    -DartifactId="$module" \
    -Dversion="$version-SNAPSHOT" \
    -Dpackage="components/$module" \
    -Ddescription="$description" \
    -Ddeveloper="$developer" \
    -Ddeveloper-email="$email" \
    -B
