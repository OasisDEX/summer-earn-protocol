#!/bin/bash

# Set the paths
FORGE_DIR="."
OUT_DIR="./out"
ABI_DIR="./src/abis"

# Create the ABI directory if it doesn't exist
mkdir -p "$ABI_DIR"

# Copy the ABI JSON files
echo "Copying ABI JSON files..."
if [ -f "$OUT_DIR/IntentHandler.sol/IntentHandler.abi.json" ]; then
    cp "$OUT_DIR/IntentHandler.sol/IntentHandler.abi.json" "$ABI_DIR/IntentHandler.abi.json"
    echo "Copied IntentHandler.abi.json"
fi

if [ -f "$OUT_DIR/IntentBondFactory.sol/IntentBondFactory.abi.json" ]; then
    cp "$OUT_DIR/IntentBondFactory.sol/IntentBondFactory.abi.json" "$ABI_DIR/IntentBondFactory.abi.json"
    echo "Copied IntentBondFactory.abi.json"
fi

if [ -f "$OUT_DIR/SolverBond.sol/SolverBond.abi.json" ]; then
    cp "$OUT_DIR/SolverBond.sol/SolverBond.abi.json" "$ABI_DIR/SolverBond.abi.json"
    echo "Copied SolverBond.abi.json"
fi

if [ -f "$OUT_DIR/Escrow.sol/Escrow.abi.json" ]; then
    cp "$OUT_DIR/Escrow.sol/Escrow.abi.json" "$ABI_DIR/Escrow.abi.json"
    echo "Copied Escrow.abi.json"
fi

echo "Done!"
