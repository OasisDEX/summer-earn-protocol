#!/bin/bash

# Deploy Intent System to Base
# Usage: ./deploy-intent-system.sh

set -e

echo "🚀 Deploying Intent System to Base..."

# Check if PRIVATE_KEY is set
if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ Error: PRIVATE_KEY environment variable is not set"
    echo "Please set your private key: export PRIVATE_KEY=0x..."
    exit 1
fi

# Check if BASE_RPC_URL is set, provide default if not
if [ -z "$BASE_RPC_URL" ]; then
    echo "⚠️  BASE_RPC_URL not set, using default Alchemy endpoint"
    export BASE_RPC_URL="https://base-mainnet.g.alchemy.com/v2/demo"
fi

echo "📡 RPC URL: $BASE_RPC_URL"
echo "🔑 Using private key: ${PRIVATE_KEY:0:6}..."

# Run the deployment
forge script script/DeployIntentSystem.s.sol \
    --rpc-url $BASE_RPC_URL \
    --broadcast \
    --verify \
    --chain-id 8453 \
    -vvvv

echo "✅ Deployment complete!"
echo ""
echo "📋 Next steps:"
echo "1. Save the deployed addresses"
echo "2. Grant necessary roles via ProtocolAccessManager"
echo "3. Register fleet commander: $USDC_FLEET"
echo "4. Add solver adapters"
echo "5. Create solver bonds"
