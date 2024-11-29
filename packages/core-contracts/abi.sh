#!/bin/bash

# Set the paths
FORGE_DIR="."
OUT_DIR="./out"
ABI_DIR="../summer-earn-protocol-subgraph/abis"

# Run the Forge build
echo "Running Forge build..."
forge build

# Create the ABI directory if it doesn't exist
mkdir -p "$ABI_DIR"

# Copy the ABI JSON files
echo "Copying ABI JSON files..."
cp "$OUT_DIR/Ark.sol/Ark.abi.json" "$ABI_DIR/Ark.abi.json"
cp "$OUT_DIR/FleetCommander.sol/FleetCommander.abi.json" "$ABI_DIR/FleetCommander.abi.json"
cp "$OUT_DIR/FleetCommanderRewardsManager.sol/FleetCommanderRewardsManager.abi.json" "$ABI_DIR/FleetCommanderRewardsManager.abi.json"

echo "Done!"