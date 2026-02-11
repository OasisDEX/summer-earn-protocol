#!/bin/bash

# Example usage:
# TICKER=SPXUX ASSET_ADDRESS=0x... SIGNERS=0x1,0x2 THRESHOLD=1 ./deploy.sh base

NETWORK=$1
if [ -z "$NETWORK" ]; then
  echo "Usage: ./deploy.sh <network>"
  exit 1
fi

# Load RPC URL from .env or foundry.toml if needed, but here we assume it's in env
RPC_URL_VAR="${NETWORK^^}_RPC_URL"
RPC_URL=${!RPC_URL_VAR}

if [ -z "$RPC_URL" ]; then
  echo "Error: $RPC_URL_VAR not set in environment"
  exit 1
fi

echo "Deploying to $NETWORK..."

# Run forge script and capture output
# We use --broadcast to actually send txs
# We need DEPLOYER_PRIVATE_KEY in env
OUTPUT=$(forge script scripts/DeployRwaOracle.s.sol:DeployRwaOracle 
  --rpc-url $RPC_URL 
  --broadcast 
  -vvvv)

echo "$OUTPUT"

# Extract addresses (this is a bit brittle but works for a simple setup)
REGISTRY_ADDR=$(echo "$OUTPUT" | grep "Deployed OracleRegistry at:" | awk '{print $4}')
ORACLE_ADDR=$(echo "$OUTPUT" | grep "Deployed RwaOracle for" | awk '{print $5}')

if [ -n "$REGISTRY_ADDR" ]; then
  echo "Updating deployments.json with new Registry: $REGISTRY_ADDR"
  # This part would ideally use 'jq' to update the JSON
  # For now, I'll just print instructions or do a simple sed if it's predictable
fi
