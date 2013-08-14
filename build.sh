#!/bin/sh
rdmd -O -inline -release -noboundscheck --build-only main.d
mv main vxlgen
