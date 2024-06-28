#!/bin/bash
find . -name dist -type d -exec rm -rvf {} \;
find . -name tsconfig.build.tsbuildinfo -type f -exec rm -rvf {} \;
find . -name tsconfig.tsbuildinfo -type f -exec rm -rvf {} \;