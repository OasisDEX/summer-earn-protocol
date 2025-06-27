# DeploymentAccessManaged

## The Problem It Solves

During deployment, you need flexibility to configure contracts, but after launch, you want governance control. The challenge: **how do you transition from deployer control to governance control safely?**

## The Solution

`DeploymentAccessManaged` provides a **two-phase lifecycle**:

### Phase 1: Deployment Phase
- **Controller**: Deployer address
- **Access**: Deployer can configure and manage the contract
- **Purpose**: Rapid setup and testing during deployment

### Phase 2: Governance Phase  
- **Controller**: Governance address (with `GOVERNOR_ROLE`)
- **Access**: Standard protocol governance controls everything
- **Purpose**: Secure, decentralized operation

## How It Works

```solidity
contract MyContract is DeploymentAccessManaged {
    constructor(address deployer, address accessManager) 
        DeploymentAccessManaged(deployer, accessManager) {}
    
    // Only works during deployment phase
    function initialSetup() external onlyDeploymentController {
        // Deployer-only configuration
    }
    
    // Works in both phases (deployer during deployment, governors after)
    function updateConfig() external onlyControllerOrGovernor {
        // Flexible configuration
    }
}
```

## The Transition

**One-way, permanent transition:**

```solidity
// 1. Deploy with deployer as controller
MyContract contract = new MyContract(deployerAddress, accessManager);

// 2. Deployer configures everything
contract.initialSetup();
contract.updateConfig();

// 3. When ready, transfer to governance (IRREVERSIBLE)
contract.transferToGovernance(governanceAddress);

// 4. Now only governance can make changes
// Deployer is permanently locked out
```

## Key Features

### Access Modifiers

- **`onlyDeploymentController`**: Only deployer, only during deployment phase
- **`onlyControllerOrGovernor`**: Deployer during deployment, governors after transition

### Automatic Phase Detection

The contract automatically detects which phase it's in:
- **Deployment Phase**: When controller is NOT a governor
- **Governance Phase**: When controller IS a governor

### Security Guarantees

1. **One-Way Transition**: Cannot go back to deployment phase
2. **Governor Verification**: New controller must have `GOVERNOR_ROLE`  
3. **Immediate Effect**: Transition happens in same transaction
4. **Clear Events**: `GovernanceModeActivated` event marks the transition

## Why This Pattern?

- **Deployment Speed**: Deployer can iterate quickly without governance delays
- **Production Security**: Full governance security after launch
- **Clear Transition**: Obvious point where deployment ends and governance begins
- **Audit Trail**: Events track the entire lifecycle

## Example Workflow

```solidity
// Week 1: Deploy and configure
deploy MyContract(deployer, accessManager)
contract.configure(...)
contract.test(...)
contract.finalize(...)

// Week 2: Transfer to governance when ready
contract.transferToGovernance(governanceMultisig)
// ✅ Now fully governed by protocol
// ❌ Deployer can no longer make changes
```

This pattern is essential for contracts that need extensive configuration during deployment but must be governance-controlled in production.