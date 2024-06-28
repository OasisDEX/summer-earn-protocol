#!/bin/bash
./bin/clean-build.sh
find . -name node_modules -type d -exec rm -rvf {} \;
find . -name cache -type d -exec rm -rvf {} \;
find . -name coverage -type d -exec rm -rvf {} \;
find . -name .turbo -type d -exec rm -rvf {} \;
