#!/bin/bash

here=$PWD

rm -Rf $here/target
cd test/perl
prove -r -v -I$here/src/main/perl -I/usr/lib/perl $@
