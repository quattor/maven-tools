#!/bin/bash

here=$PWD

rm -Rf $here/target

prove -r -v -I$here/src/main/perl -I/usr/lib/perl src/test/perl/$1
