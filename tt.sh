#!/bin/bash

submodules=(
    "packages/core-contracts/lib/openzeppelin-contracts"
    "packages/core-contracts/lib/prb-math"
    "packages/core-contracts/lib/forge-std"
    "packages/core-contracts/lib/metamorpho"
    "packages/core-contracts/lib/morpho-blue"
    "packages/core-contracts/lib/pendle-core-v2-public"
    "packages/core-contracts/lib/openzeppelin-contracts-upgradeable"
)

for submodule in "${submodules[@]}"
do
    echo "Removing submodule $submodule"
    git submodule deinit -f "$submodule"
    rm -rf ".git/modules/$submodule"
    git rm -f "$submodule"
done

# Commit the changes
git add .gitmodules
git commit -m "Remove old submodules"