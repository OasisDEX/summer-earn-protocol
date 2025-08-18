# Intent System Deployment Guide

This guide covers deploying the complete Intent System on Base using the modular architecture with `GenericIntentArk`, `AaveV3Escrow`, and `IntentHandler`.

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ GenericIntentArk│    │  IntentHandler   │    │ IntentBondFactory│
│                 │    │                  │    │                 │
│ - postIntent()  │───▶│ - createIntent() │    │ - createBond()  │
│ - cancelIntent()│    │ - solveIntent()  │    │ - slashBond()   │
└─────────────────┘    │ - settleIntent() │    └─────────────────┘
                       └──────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │  AaveV3Escrow   │
                       │                 │
                       │ - deposit()     │
                       │ - withdraw()    │
                       └─────────────────┘
```

## Deployment Steps

### 1. Prerequisites

- Set up environment variables:
```bash
export PRIVATE_KEY=0x...
export BASE_RPC_URL=https://base-mainnet.g.alchemy.com/v2/YOUR_KEY
```

- Ensure you have sufficient ETH on Base for deployment

### 2. Deploy Core Contracts

Run the deployment script:

```bash
cd packages/core-contracts
./deploy-intent-system.sh
```

This will deploy:
- `IntentBondFactory` - Manages solver bonds
- `MockIntentOracle` - Price oracle (temporary)
- `IntentHandler` - Core intent lifecycle management
- `GenericIntentArk` - Generic ark for USDC intents
- `AaveV3Escrow` - Aave V3 protocol adapter

### 3. Configuration

Update the addresses in `ConfigureIntentSystem.s.sol` and run:

```bash
forge script script/ConfigureIntentSystem.s.sol --rpc-url $BASE_RPC_URL --broadcast
```

### 4. Verification

Update addresses in `VerifyIntentSystem.s.sol` and run:

```bash
forge script script/VerifyIntentSystem.s.sol --rpc-url $BASE_RPC_URL
```

## Deployed Addresses (Base)

### Infrastructure (Existing)
- **Summer Token**: `0x932CCb7D2A6F1821a1Ecee9e1279aC30E0d4db32`
- **Protocol Access Manager**: `0x603821f86DeDC794A3225d62Afe1F175fe4AE861`
- **Configuration Manager**: `0x17134eCce2bfDE9cfbd05D0faFfCB2e262E81eA1`
- **USDC**: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- **USDC Fleet**: `0xf762b4E90b21be81E5673058ac01B83A5833A4d9`

### Aave V3 (Base)
- **Pool**: `0xA238Dd80C259a72e81d7e4664a9801593F98d1c5`
- **Rewards Controller**: `0xf9cc4F0D883F1a1eb2c253bdb46c254Ca51E1F44`

### Intent System (To be deployed)
- **IntentBondFactory**: `TBD`
- **MockIntentOracle**: `TBD`
- **IntentHandler**: `TBD`
- **GenericIntentArk**: `TBD`
- **AaveV3Escrow**: `TBD`

## Post-Deployment Configuration

### 1. Role Management

Grant necessary roles via `ProtocolAccessManager`:

```solidity
// Grant KEEPER_ROLE to fleet commander
accessManager.grantRole(KEEPER_ROLE, USDC_FLEET, 0);

// Grant SOLVER_ROLE to solvers
accessManager.grantRole(SOLVER_ROLE, solverAddress, 0);

// Grant ARK_ROLE to intent handler
accessManager.grantRole(ARK_ROLE, INTENT_HANDLER, 0);
```

### 2. Fleet Commander Registration

Fleet commander must register with the ark:

```solidity
// Called by fleet commander
genericIntentArk.registerFleetCommander();
```

### 3. Solver Setup

For each solver:

1. Create a solver bond:
```solidity
address bondAddress = intentBondFactory.createBond(solverAddress);
```

2. Add adapter mapping:
```solidity
intentHandler.addSolverAdapter(solverAddress, AAVE_V3_ESCROW);
```

3. Solver adds bond:
```solidity
// Called by solver
IERC20(summerToken).approve(bondAddress, bondAmount);
SolverBond(bondAddress).addBond(bondAmount);
```

## Usage Flow

### 1. Post Intent

Fleet commander posts an intent:

```solidity
bytes32 intentId = keccak256("unique-intent-id");
ark.postIntent(
    intentId,
    1000e6,        // 1000 USDC
    30 days,       // 30 day term
    50e6,          // 50 USDC target yield
    oracleAddress,
    block.timestamp + 1 days // expires in 1 day
);
```

### 2. Solve Intent

Solver provides liquidity:

```solidity
// Approve tokens
IERC20(usdc).approve(address(intentHandler), escrowAmount);

// Solve intent
intentHandler.solveIntent(
    address(ark),
    solverAddress,
    50e6  // escrowed yield
);
```

### 3. Settle Intent

After term completion:

```solidity
intentHandler.settleIntent(address(ark));
```

## Security Considerations

1. **Access Control**: All functions use role-based access control via `ProtocolAccessManager`
2. **Bond Requirements**: Solvers must maintain sufficient bonds to cover potential slashing
3. **Oracle Dependencies**: Price verification relies on oracle accuracy
4. **Slashing Mechanism**: 50% bond slash for solver resignation

## Monitoring

Key events to monitor:
- `IntentPosted` - New intents created
- `IntentSolved` - Intents matched with solvers
- `IntentSettled` - Successful completion
- `IntentResignedBySolver` - Solver resignations (with slashing)

## Troubleshooting

### Common Issues

1. **Role Permissions**: Ensure all addresses have correct roles
2. **Token Approvals**: Check token approvals for all transfers
3. **Bond Sufficiency**: Verify solver bonds meet requirements
4. **Oracle Configuration**: Ensure oracle supports all required tokens

### Debug Commands

```bash
# Check contract deployment
cast code $CONTRACT_ADDRESS --rpc-url $BASE_RPC_URL

# Check role assignments
cast call $ACCESS_MANAGER "hasRole(bytes32,address)" $ROLE $ADDRESS --rpc-url $BASE_RPC_URL

# Check token balances
cast call $TOKEN "balanceOf(address)" $ADDRESS --rpc-url $BASE_RPC_URL
```

## Next Steps

1. Deploy to testnet first for validation
2. Set up monitoring and alerting
3. Create solver onboarding process
4. Implement additional protocol adapters (Morpho, Compound, etc.)
5. Replace MockIntentOracle with production oracle
6. Set up automated keeper operations
