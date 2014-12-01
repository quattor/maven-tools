#!/bin/bash

rm -Rf $PWD/target

prove -r -v -I$PWD/src/main/perl -I/usr/lib/perl src/test/perl/$1
