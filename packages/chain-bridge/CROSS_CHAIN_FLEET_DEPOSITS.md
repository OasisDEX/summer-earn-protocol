# Cross-Chain Fleet Deposits - Vendor Agnostic Architecture

## Overview

The Summer Protocol now supports **vendor-agnostic** cross-chain fleet deposits, allowing users to deposit assets from one chain directly to FleetCommanders on another chain using their preferred bridge technology. This architecture provides flexibility and future-proofs the system against bridge technology changes.

## Architecture

### 🏗️ Core Components

1. **FleetDepositManager**: Main orchestrator contract that users interact with
2. **IFleetDepositAdapter**: Interface implemented by bridge adapters  
3. **Bridge Adapters**: Implementation-specific adapters (StargateAdapter, HyperlaneAdapter, etc.)

### 🔄 Vendor Agnostic Design

Users can choose their preferred bridge technology:
- **Stargate V2**: Fast, secure, and widely supported
- **LayerZero**: Direct messaging protocol
- **Hyperlane**: Modular interoperability framework
- **Future bridges**: Easy to add new bridge technologies

```mermaid
graph TB
    %% Source Chain (Arbitrum)
    subgraph "Source Chain (Arbitrum)"
        User[User with USDC] --> |chooses bridge| FleetDepositManager[FleetDepositManager]
        FleetDepositManager --> |uses specified| IFleetDepositAdapter{IFleetDepositAdapter}
        IFleetDepositAdapter --> StargateAdapter[StargateAdapter]
        IFleetDepositAdapter --> HyperlaneAdapter[HyperlaneAdapter]
        IFleetDepositAdapter --> LayerZeroAdapter[LayerZeroAdapter]
        IFleetDepositAdapter --> FutureAdapter[Future Bridge Adapters]
    end
    
    %% Cross-Chain Bridge
    StargateAdapter --> |bridge assets + compose message| Bridge[Cross-Chain Bridge Network]
    HyperlaneAdapter --> |bridge assets + compose message| Bridge
    LayerZeroAdapter --> |bridge assets + compose message| Bridge
    FutureAdapter --> |bridge assets + compose message| Bridge
    
    %% Destination Chain (Base)
    subgraph "Destination Chain (Base)"
        Bridge --> |lzCompose callback| DestAdapter[Destination Bridge Adapter]
        DestAdapter --> |deposit on behalf of user| FleetCommander[Base USDC Fleet]
        FleetCommander --> |mints shares to| ShareRecipient[User's Address]
    end
    
    %% Styling
    classDef userStyle fill:#90EE90,stroke:#333,stroke-width:2px
    classDef managerStyle fill:#DDA0DD,stroke:#333,stroke-width:2px
    classDef adapterStyle fill:#FFB6C1,stroke:#333,stroke-width:2px
    classDef bridgeStyle fill:#87CEEB,stroke:#333,stroke-width:3px
    classDef fleetStyle fill:#F4A460,stroke:#333,stroke-width:2px
    
    class User,ShareRecipient userStyle
    class FleetDepositManager managerStyle
    class StargateAdapter,HyperlaneAdapter,LayerZeroAdapter,FutureAdapter,DestAdapter adapterStyle
    class Bridge bridgeStyle
    class FleetCommander fleetStyle
```

### 🎯 Benefits of Vendor Agnostic Design

1. **User Choice**: Users can select their preferred bridge based on fees, speed, or trust preferences
2. **Risk Diversification**: Not dependent on a single bridge technology
3. **Future-Proof**: Easy to add support for new bridge technologies
4. **Competitive Fees**: Bridges compete on pricing and features
5. **Reduced Vendor Lock-in**: No dependency on any specific bridge protocol
6. **Modularity**: Bridge logic separated from fleet deposit logic

### 🔌 How to Add New Bridge Adapters

To support a new bridge technology:

1. **Implement Interface**: Create adapter implementing `IFleetDepositAdapter`
2. **Register with BridgeRouter**: Use existing governance process
3. **Users Can Use**: Immediately available to all users

```solidity
// Example: Adding Hyperlane support
contract HyperlaneAdapter is IFleetDepositAdapter, IBridgeAdapter {
    function executeCrossChainFleetDeposit(...) external payable override {
        // Hyperlane-specific implementation
    }
    
    function supportsFleetDeposits() external pure override returns (bool) {
        return true;
    }
    
    // ... standard IBridgeAdapter methods
}

// Governance registers the new adapter with BridgeRouter (existing process)
bridgeRouter.registerAdapter(hyperlaneAdapter);
```

## Multi-Chain Deposit Hub Architecture

The cross-chain fleet deposit system enables a **Hub CrossChain Fleet** (deployed on a primary chain like Base) to receive deposits from users across multiple source chains. This creates a unified liquidity hub that aggregates capital from the entire ecosystem.

### 🌐 Hub Fleet Deposit Flow

```mermaid
graph TB
    %% Source Chains with Users
    subgraph "Ethereum Mainnet"
        UserETH[Users with USDC<br/>10,000 USDC] --> FleetDepMgrETH[FleetDepositManager]
        FleetDepMgrETH --> AdapterETH[Bridge Adapter]
    end
    
    subgraph "Arbitrum"
        UserARB[Users with USDC<br/>5,000 USDC] --> FleetDepMgrARB[FleetDepositManager] 
        FleetDepMgrARB --> AdapterARB[Bridge Adapter]
    end
    
    subgraph "Polygon"
        UserPOL[Users with USDC<br/>15,000 USDC] --> FleetDepMgrPOL[FleetDepositManager]
        FleetDepMgrPOL --> AdapterPOL[Bridge Adapter]
    end
    
    subgraph "Optimism"
        UserOP[Users with USDC<br/>20,000 USDC] --> FleetDepMgrOP[FleetDepositManager]
        FleetDepMgrOP --> AdapterOP[Bridge Adapter]
    end
    
    %% Bridge Network
    AdapterETH --> |Cross-Chain Bridge| BridgeNetwork[Multi-Chain Bridge Network]
    AdapterARB --> |Cross-Chain Bridge| BridgeNetwork
    AdapterPOL --> |Cross-Chain Bridge| BridgeNetwork  
    AdapterOP --> |Cross-Chain Bridge| BridgeNetwork
    
    %% Hub Chain (Base) - Simplified to show just the entry point
    subgraph "Base Chain (Hub)"
        BridgeNetwork --> |All USDC Deposits| HubAdapter[Base Bridge Adapter]
        HubAdapter --> |50,000 USDC Total| HubFleet[Hub CrossChain USDC Fleet]
    end
    
    %% Styling
    classDef userStyle fill:#90EE90,stroke:#333,stroke-width:2px
    classDef managerStyle fill:#DDA0DD,stroke:#333,stroke-width:2px
    classDef adapterStyle fill:#FFB6C1,stroke:#333,stroke-width:2px
    classDef bridgeStyle fill:#87CEEB,stroke:#333,stroke-width:3px
    classDef hubFleetStyle fill:#FF6B6B,stroke:#333,stroke-width:4px
    
    class UserETH,UserARB,UserPOL,UserOP userStyle
    class FleetDepMgrETH,FleetDepMgrARB,FleetDepMgrPOL,FleetDepMgrOP managerStyle
    class AdapterETH,AdapterARB,AdapterPOL,AdapterOP,HubAdapter adapterStyle
    class BridgeNetwork bridgeStyle
    class HubFleet hubFleetStyle
```

### 🎯 Hub Architecture Benefits

1. **Unified Liquidity Pool**: Aggregates deposits from all supported chains into one managed fleet
2. **Cross-Chain Yield Optimization**: Hub fleet can deploy capital to the highest-yielding opportunities across all chains
3. **Simplified User Experience**: Users deposit from any chain but receive shares in a professionally managed cross-chain portfolio
4. **Economies of Scale**: Larger capital pool enables access to institutional-grade opportunities
5. **Risk Distribution**: Capital automatically distributed across multiple chains and protocols
6. **Single Governance**: Centralized strategy decisions with decentralized execution

### 📊 Capital Flow Example

**Scenario**: Hub USDC Fleet on Base receiving deposits from multiple chains

1. **Ethereum User**: Deposits 10,000 USDC → Bridged to Base → 10,000 Hub Fleet shares sent to user's Base EOA
2. **Arbitrum User**: Deposits 5,000 USDC → Bridged to Base → 5,000 Hub Fleet shares sent to user's Base EOA  
3. **Polygon User**: Deposits 15,000 USDC → Bridged to Base → 15,000 Hub Fleet shares sent to user's Base EOA
4. **Optimism User**: Deposits 20,000 USDC → Bridged to Base → 20,000 Hub Fleet shares sent to user's Base EOA

**Result**: 
- **Hub Fleet**: Receives 50,000 USDC total from all chains for professional multi-chain management
- **Users**: Each receives fleet shares in their Base chain EOA proportional to their deposit
- **Management**: Hub fleet handles all cross-chain deployment and yield optimization behind the scenes

### 🔄 Dynamic Rebalancing

The Hub Fleet can dynamically rebalance across chains based on:
- **Yield Opportunities**: Move capital to chains with better rates
- **Risk Assessment**: Reduce exposure to chains with elevated risk
- **Market Conditions**: Adapt to changing DeFi landscape
- **User Demand**: Allocate based on deposit patterns

### 🛡️ Safety Features

- **Multi-Chain Validation**: Ensures fleet compatibility before accepting deposits
- **Bridge Redundancy**: Multiple bridge options reduce single points of failure
- **Emergency Pause**: Can halt deposits if issues detected on any chain
- **Governance Recovery**: Manual intervention capabilities for edge cases

## Use Cases

1. **User has USDC on Arbitrum, wants to deposit to USDC Fleet on Base**
2. **User has USDT on Ethereum, wants to deposit to USDT Fleet on Polygon** 
3. **User wants to use referral codes for tracking/rewards**
4. **Batch deposits for multiple users via aggregator contracts**

## Key Features

### 🚀 Core Functionality
- **Single Transaction**: Bridge + Deposit in one transaction
- **Referral Support**: Built-in referral code tracking
- **Fee Estimation**: Accurate cross-chain fee calculation
- **Error Recovery**: Robust failure handling and manual recovery

### 🔒 Safety Features
- **Composability Safety**: Uses Stargate V2's compose functionality
- **Failed Operation Tracking**: Records and allows recovery of failed deposits
- **Asset Validation**: Validates FleetCommander compatibility before deposit
- **Governance Recovery**: Manual recovery for edge cases

## Implementation Details

### New Functions Added

#### `crossChainDepositToFleet()`
```solidity
function crossChainDepositToFleet(
    address bridgeAdapter,
    uint16 destinationChainId,
    address asset,
    uint256 amount,
    address fleetCommander,
    address shareRecipient,
    bytes memory referralCode,
    BridgeTypes.AdapterParams calldata adapterParams
) external payable nonReentrant returns (bytes32 operationId)
```

Main function for users to deposit assets cross-chain to FleetCommanders. Users choose their preferred bridge adapter.

#### `encodeFleetDepositMessage()`
```solidity
function encodeFleetDepositMessage(
    address fleetCommander,
    address shareRecipient,
    address asset,
    uint256 amount,
    bytes memory referralCode
) external view returns (bytes memory composeMessage)
```

Encodes a fleet deposit compose message for fee estimation and bridge adapter usage.

### Enhanced Compose Message Handling

The adapter now supports two types of compose messages:
1. **Legacy Asset Transfer** (existing functionality)
2. **Fleet Deposit** (new functionality)

Messages are differentiated by a type identifier in the first 32 bytes.

### Fleet Deposit Flow

```mermaid
sequenceDiagram
    participant User as User (Arbitrum)
    participant FleetDepositManager as FleetDepositManager (Arbitrum)
    participant SourceAdapter as StargateAdapter (Arbitrum)  
    participant Stargate as Stargate Network
    participant LayerZero as LayerZero Network
    participant DestAdapter as StargateAdapter (Base)
    participant FleetCommander as USDC Fleet (Base)
    participant ShareRecipient as User Address (Base)

    Note over User,ShareRecipient: Cross-Chain Fleet Deposit Flow
    
    %% Source Chain Operations
    User->>FleetDepositManager: crossChainDepositToFleet(stargateAdapter, Base, ...)
    Note over User,FleetDepositManager: User chooses Stargate as bridge adapter
    
    FleetDepositManager->>SourceAdapter: executeCrossChainFleetDeposit()
    Note over FleetDepositManager,SourceAdapter: Includes fleet deposit compose message
    
    SourceAdapter->>Stargate: sendToken() with fleet compose message
    Note over SourceAdapter,Stargate: USDC + encoded fleet deposit instruction
    
    %% Cross-Chain Bridge
    Stargate->>LayerZero: Cross-chain message + assets
    Note over Stargate,LayerZero: Bridging USDC from Arbitrum to Base
    
    %% Destination Chain Operations  
    LayerZero->>DestAdapter: lzCompose(fleetDepositMessage)
    Note over LayerZero,DestAdapter: Callback with bridged USDC + compose data
    
    DestAdapter->>FleetCommander: deposit(amount, shareRecipient, referralCode)
    Note over DestAdapter,FleetCommander: Deposit bridged USDC on behalf of user
    
    FleetCommander->>ShareRecipient: Transfer fleet shares
    Note over FleetCommander,ShareRecipient: User receives shares on destination chain
    
    %% Success Event
    DestAdapter-->>User: CrossChainFleetDepositCompleted event
    Note over DestAdapter,User: Event emitted for frontend tracking
```

## Usage Examples

### Basic Cross-Chain Fleet Deposit (Vendor Agnostic)

```solidity
// User on Arbitrum wants to deposit USDC to Summer's Base USDC Fleet using Stargate
contract MyContract {
    function depositToBaseFleet(
        address fleetDepositManager,
        address stargateAdapter,
        address usdcToken,
        address baseFleetCommander,
        uint256 amount
    ) external {
        // 1. User approves FleetDepositManager to spend their USDC
        IERC20(usdcToken).approve(fleetDepositManager, amount);

        // 2. Create fleet deposit message for fee estimation
        bytes memory composeMessage = IFleetDepositManager(fleetDepositManager)
            .encodeFleetDepositMessage(
                baseFleetCommander,
                msg.sender, // share recipient
                usdcToken,
                amount,
                bytes("") // no referral code
            );

        // 3. Estimate fee using adapter's standard estimateFee
        (uint256 nativeFee, ) = IBridgeAdapter(stargateAdapter)
            .estimateFee(
                8453, // Base chain ID
                usdcToken,
                amount,
                BridgeTypes.AdapterParams({
                    gasLimit: 500000, // Higher gas for fleet operations
                    calldataSize: 0,
                    msgValue: 0,
                    options: composeMessage // Pass compose message here
                }),
                BridgeTypes.OperationType.TRANSFER_ASSET
            );

        // 4. Execute cross-chain deposit through chosen bridge adapter
        IFleetDepositManager(fleetDepositManager).crossChainDepositToFleet{
            value: nativeFee
        }(
            stargateAdapter, // User's choice: could be hyperlaneAdapter, layerZeroAdapter, etc.
            8453, // Base chain ID
            usdcToken,
            amount,
            baseFleetCommander,
            msg.sender, // User receives the fleet shares
            bytes(""), // No referral code
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            })
        );
    }
}
```

### Cross-Chain Deposit with Referral Code

```solidity
function depositWithReferral(
    address fleetDepositManager,
    address stargateAdapter, // User's choice of bridge
    address token,
    address fleetCommander,
    uint16 destinationChainId,
    uint256 amount,
    string memory referralCode
) external {
    IERC20(token).approve(fleetDepositManager, amount);

    bytes memory referralCodeBytes = bytes(referralCode);

    // Create compose message for fee estimation
    bytes memory composeMessage = IFleetDepositManager(fleetDepositManager)
        .encodeFleetDepositMessage(
            fleetCommander,
            msg.sender, // share recipient
            token,
            amount,
            referralCodeBytes
        );

    // Estimate fee using chosen bridge adapter
    (uint256 nativeFee, ) = IBridgeAdapter(stargateAdapter)
        .estimateFee(
            destinationChainId,
            token,
            amount,
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: composeMessage
            }),
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

    // Execute through FleetDepositManager (vendor agnostic)
    IFleetDepositManager(fleetDepositManager).crossChainDepositToFleet{
        value: nativeFee
    }(
        stargateAdapter, // User's choice: could be any registered adapter
        destinationChainId,
        token,
        amount,
        fleetCommander,
        msg.sender,
        referralCodeBytes,
        BridgeTypes.AdapterParams({
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: bytes("")
        })
    );
}
```

### Integration with DEX (Swap + Cross-Chain Deposit)

```solidity
function swapAndCrossChainDeposit(
    address dexRouter,
    address fleetDepositManager,
    address stargateAdapter, // User's choice of bridge
    address inputToken,
    address outputToken,
    uint256 inputAmount,
    uint256 minOutputAmount,
    address fleetCommander,
    uint16 destinationChainId
) external payable {
    // 1. Swap on local chain
    IERC20(inputToken).safeTransferFrom(msg.sender, address(this), inputAmount);
    IERC20(inputToken).approve(dexRouter, inputAmount);

    uint256 outputAmount = IDEXRouter(dexRouter).swapExactTokensForTokens(
        inputAmount,
        minOutputAmount,
        inputToken,
        outputToken
    );

    // 2. Cross-chain deposit the swapped tokens
    IERC20(outputToken).approve(fleetDepositManager, outputAmount);

    IFleetDepositManager(fleetDepositManager).crossChainDepositToFleet{
        value: msg.value
    }(
        stargateAdapter, // User's choice of bridge adapter
        destinationChainId,
        outputToken,
        outputAmount,
        fleetCommander,
        msg.sender,
        bytes("SWAP_AND_DEPOSIT"),
        BridgeTypes.AdapterParams({
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: bytes("")
        })
    );
}
```

### Batch Processing Multiple Users

```solidity
function batchFleetDeposits(
    address fleetDepositManager,
    address stargateAdapter, // User's choice of bridge
    address token,
    address fleetCommander,
    uint16 destinationChainId,
    address[] memory users,
    uint256[] memory amounts
) external payable {
    require(users.length == amounts.length, "Array length mismatch");

    uint256 totalAmount = 0;
    for (uint256 i = 0; i < amounts.length; i++) {
        totalAmount += amounts[i];
        IERC20(token).safeTransferFrom(users[i], address(this), amounts[i]);
    }

    IERC20(token).approve(fleetDepositManager, totalAmount);

    // Execute single cross-chain deposit for all users
    // Note: In production, you'd need logic to distribute shares proportionally
    IFleetDepositManager(fleetDepositManager).crossChainDepositToFleet{
        value: msg.value
    }(
        stargateAdapter, // User's choice of bridge adapter
        destinationChainId,
        token,
        totalAmount,
        fleetCommander,
        address(this), // This contract receives shares temporarily
        bytes("BATCH_DEPOSIT"),
        BridgeTypes.AdapterParams({
            gasLimit: 750000, // Higher gas for batch processing
            calldataSize: 0,
            msgValue: 0,
            options: bytes("")
        })
    );
}
```

## Enhanced Fee Estimation

The `StargateAdapter.estimateFee()` function has been enhanced to handle both legacy transfers and fleet deposits through a flexible compose message system:

### Usage Patterns

**For Fleet Deposits (with compose message):**
```solidity
// Create fleet deposit compose message for accurate fee estimation
bytes memory composeMsg = IFleetDepositManager(fleetDepositManager)
    .encodeFleetDepositMessage(
        fleetCommander,
        shareRecipient,
        asset,
        amount,
        referralCode
    );

(uint256 nativeFee, ) = IBridgeAdapter(stargateAdapter).estimateFee(
    destinationChainId,
    asset,
    amount,
    BridgeTypes.AdapterParams({
        gasLimit: 500000, // Higher gas for fleet operations
        calldataSize: 0,
        msgValue: 0,
        options: composeMsg // Compose message for accurate sizing
    }),
    BridgeTypes.OperationType.TRANSFER_ASSET
);
```

**For Legacy Transfers (without compose message):**
```solidity
// Legacy format - uses dummy compose message for estimation
(uint256 nativeFee, ) = adapter.estimateFee(
    destinationChainId,
    asset,
    amount,
    BridgeTypes.AdapterParams({
        gasLimit: 300000, // Standard gas
        calldataSize: 0,
        msgValue: 0,
        options: bytes("") // Empty - uses fallback dummy message
    }),
    BridgeTypes.OperationType.TRANSFER_ASSET
);
```

### Benefits

1. **Accurate Pricing**: Uses actual compose message size for precise fee calculation
2. **Variable Gas Limits**: Allows custom gas limits via `adapterParams.gasLimit`
3. **Referral Code Support**: Accounts for variable message sizes due to referral codes
4. **Backward Compatible**: Empty `options` falls back to dummy message for legacy compatibility
5. **Single Function**: Eliminates need for separate fee estimation functions

### Error Handling and Recovery

```solidity
function checkAndRecoverFailedDeposits(
    address stargateAdapter,
    address governance
) external {
    require(msg.sender == governance, "Only governance");

    bytes32[] memory failedOps = IStargateAdapter(stargateAdapter).getFailedOperations();
    
    for (uint256 i = 0; i < failedOps.length; i++) {
        (
            address asset,
            uint256 amount,
            address intendedRecipient,
            bytes32 operationId,
            address originator,
            ,
            ,
        ) = IStargateAdapter(stargateAdapter).failedComposes(failedOps[i]);

        // Recover tokens to the original user
        IStargateAdapter(stargateAdapter).manualRecovery(
            asset,
            amount,
            originator, // Send back to original user
            operationId,
            false, // Don't retry fleet deposit
            bytes("")
        );
    }
}
```

### Utility Functions

```solidity
// Check if chain and asset are supported
function checkSupport(
    address stargateAdapter,
    uint16 chainId,
    address asset
) external view returns (bool chainSupported, bool assetSupported) {
    chainSupported = IStargateAdapter(stargateAdapter).supportsChain(chainId);
    assetSupported = IStargateAdapter(stargateAdapter).isAssetSupported(chainId, asset);
}

// Estimate fees for multiple amounts
function estimateFeesForAmounts(
    address fleetDepositManager,
    address stargateAdapter,
    uint16 destinationChainId,
    address asset,
    address fleetCommander,
    uint256[] memory amounts,
    bytes memory referralCode
) external view returns (uint256[] memory fees) {
    fees = new uint256[](amounts.length);

    for (uint256 i = 0; i < amounts.length; i++) {
        // Create proper compose message for fee estimation
        bytes memory composeMsg = IFleetDepositManager(fleetDepositManager)
            .encodeFleetDepositMessage(
                fleetCommander,
                address(0xdead), // dummy share recipient
                asset,
                amounts[i],
                referralCode
            );

        (fees[i], ) = IBridgeAdapter(stargateAdapter).estimateFee(
            destinationChainId,
            asset,
            amounts[i],
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: composeMsg
            }),
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
    }
}
```

## Testing

### Unit Tests
- **Mock FleetCommander Tests**: `StargateAdapter.CrossChainFleet.t.sol`
- Covers basic functionality, error cases, and edge scenarios

### Integration Tests  
- **Real FleetCommander Tests**: `StargateAdapter.FleetIntegration.t.sol`
- Tests with actual Summer Protocol FleetCommander contracts
- End-to-end testing of the complete flow

### Demo Contract
- **Usage Examples**: `CrossChainFleetDepositDemo.sol`
- Practical examples for different use cases
- Integration patterns and monitoring examples

## Supported Chains & Assets

The functionality works with any chain and asset combination that:
1. Is supported by Stargate V2
2. Has StargateAdapter deployed on both source and destination chains
3. Has the asset configured in the adapter's `assetToStargateContract` mapping

## Gas Considerations

- **Source Chain**: Standard bridge transaction + compose overhead
- **Destination Chain**: Fleet deposit gas is covered by the bridging fee
- **Fee Estimation**: Includes compose gas in the quote

## Security Considerations

### Validation
- FleetCommander asset compatibility validation
- Deposit limit checks via `maxDeposit()`
- Chain and asset support validation

### Failure Scenarios
- FleetCommander deposit failures (deposit cap exceeded, paused, etc.)
- Invalid FleetCommander addresses
- Insufficient adapter balance
- LayerZero delivery failures

### Recovery Mechanisms
- Failed operations tracking
- Governance-controlled manual recovery
- Asset validation before operations

## Future Enhancements

1. **Batch Operations**: Support for multiple fleet deposits in one transaction
2. **Slippage Protection**: Minimum share amount guarantees  
3. **Auto-retry**: Automatic retry mechanism for recoverable failures
4. **Fee Optimization**: Dynamic gas limit adjustment based on fleet complexity

## Events

### CrossChainFleetDepositInitiated
Emitted when a user initiates a cross-chain fleet deposit.

### CrossChainFleetDepositCompleted  
Emitted when a cross-chain fleet deposit completes successfully.

### CrossChainFleetDepositFailed
Emitted when a cross-chain fleet deposit fails.

### ComposeFailedAssetsHeld
Emitted when assets are held for governance recovery after a failure.

## Integration Guide

For projects wanting to integrate cross-chain fleet deposits:

1. **Frontend Integration**:
   - Call `estimateFleetDepositFee()` for fee quotes
   - Use `crossChainDepositToFleet()` for execution
   - Monitor events for operation status

2. **Smart Contract Integration**:
   - Approve tokens before calling
   - Include sufficient ETH for fees
   - Handle potential failures gracefully

3. **Backend Integration**:
   - Monitor failed operations for manual intervention
   - Track referral codes for rewards/analytics
   - Set up alerts for stuck operations

## Conclusion

The cross-chain fleet deposit functionality provides a seamless user experience for depositing assets to Summer Protocol fleets across different chains. The **vendor-agnostic architecture** allows users to choose their preferred bridge technology, reducing vendor lock-in and providing flexibility for different use cases. The implementation prioritizes safety, recoverability, and user experience while maintaining the composability benefits of bridge protocols like Stargate V2.

Key architectural benefits:
- **User Choice**: Users select their preferred bridge adapter at call time
- **No Vendor Lock-in**: Easy to switch between bridge technologies
- **Future-Proof**: New bridge adapters can be added without protocol changes
- **Competitive Ecosystem**: Bridges compete on fees, speed, and reliability 