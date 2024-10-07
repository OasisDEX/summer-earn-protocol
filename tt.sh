#!/bin/bash

submodules=(
    "packages/core-contracts/lib/openzeppelin-contracts"
    "packages/core-contracts/lib/prb-math"
    "packages/core-contracts/lib/forge-std"
    "packages/core-contracts/lib/metamorpho"
    "packages/core-contracts/lib/morpho-blue"
    "packages/core-contracts/lib/pendle-core-v2-public"
    "packages/core-contracts/lib/openzeppelin-contracts-upgradeable"
    "packages/dutch-auction/lib/openzeppelin-contracts"
    "packages/dutch-auction/lib/forge-std"
    "packages/dutch-auction/lib/prb-math"
    "packages/voting-decay/lib/openzeppelin-contracts"
    "packages/voting-decay/lib/forge-std"
    "packages/voting-decay/lib/prb-math"
    "packages/gov-contracts/lib/forge-std"
    "packages/gov-contracts/lib/openzeppelin-contracts-upgradeable"
    "packages/gov-contracts/lib/prb-math"
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