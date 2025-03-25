# Chain Bridge System

This directory contains the implementation of a modular cross-chain bridge system that enables secure asset transfers and message passing between different blockchains. The system is designed to be extensible, allowing multiple bridge adapters to be used based on efficiency, security, and cost considerations.

## Core Components

- **BridgeRouter**: Central contract that coordinates all cross-chain operations
- **Bridge Adapters**: Protocol-specific implementations (LayerZero, Stargate, etc.)
- **CrossChainReceiver**: Interface for contracts that need to receive cross-chain data

## Cross-Chain Message Transmission

### Message Flow

```
Source Chain                                          Destination Chain
+-------------+       +-------------+                  +-------------+       +-------------+
|             |       |             |      Cross       |             |       |             |
| Application +------>+ BridgeRouterA+---------------->+ BridgeAdapterB+----->+ Recipient   |
|             |       |             |      Chain       |             |       |             |
+-------------+       +------+------+                  +------+------+       +-------------+
                             |                                |
                             v                                |
                      +-------------+                         |
                      |             |                         |
                      | BridgeAdapterA|                       |
                      |             |                         |
                      +------+------+                         |
                             |                                |
                             |                                |
                             |                         +------v------+
                             |                         |             |
                             |                         | BridgeRouterB|
                             |                         |             |
                             |                         +------+------+
                             |                                |
                             |          Confirmation          |
                             +<-------------------------------+
                                       Message
```

### Adapter Selection

1. **Explicit Selection**: Users can specify a preferred adapter via `options.specifiedAdapter`

2. **Automatic Selection**: If no adapter is specified, the router selects the best one:
   ```solidity
   function getBestAdapter(
       uint16 destinationChainId, 
       address asset, 
       uint256 amount
   ) public view returns (address)
   ```

   Selection criteria:
   - Adapter must support the destination chain
   - Adapter must support the asset (if an asset transfer)
   - Adapter must have the required capabilities (messaging, asset transfer, etc.)
   - Among valid adapters, select the one with lowest fee

3. **Specialized Selection**:
   - For asset transfers: `getBestAdapterForTransfer()`
   - For messaging: `getBestAdapterForMessaging()`
   - For state reads: `getBestAdapterForStateRead()`

## Transfer Status Management

### Status Lifecycle

Transfers progress through a series of states:
1. `UNKNOWN`: Initial state (transfer ID not recognized)
2. `PENDING`: Transfer initiated but not yet confirmed
3. `DELIVERED`: Assets delivered on destination chain
4. `COMPLETED`: Final status after confirmation is received on source chain
5. `FAILED`: Transfer failed at any point

```
                  +----------+
                  |          |
                  |  PENDING |
                  |          |
                  +----+-----+
                       |
                       v
             +-----------------+
             |                 |
             |    DELIVERED    |
             |                 |
             +--------+--------+
                      |
                      v
             +-----------------+
             |                 |
             |    COMPLETED    |
             |                 |
             +-----------------+
                      ^
                      |
             +-----------------+
             |                 |
+----------->|     FAILED      |
|            |                 |
+------------+-----------------+
```

### Status Updates

1. **Automatic Updates**:
   - `notifyTransferReceived()`: Called by adapter on destination to update to DELIVERED
   - `receiveConfirmation()`: Called when confirmation message is received to update to COMPLETED

2. **Manual Recovery**:
   - `recoverTransferStatus()`: Called by governance/guardians to manually update status when automation fails

## Fee Handling

### Fee Estimation

1. **Quote Process**: 
   ```solidity
   function _quote(
       uint16 destinationChainId,
       address asset,
       uint256 amount,
       BridgeTypes.BridgeOptions memory options,
       address preselectedAdapter
   ) internal view returns (uint256 nativeFee, uint256 tokenFee, address selectedAdapter)
   ```

2. **Fee Components**:
   - **Base Fee**: Cost of the primary cross-chain operation (returned by adapter's `estimateFee()`)
   - **Fee Multiplier**: System applies a multiplier to cover confirmation costs
     ```solidity
     uint256 public feeMultiplier = 200; // 200% = double fee
     ```
   - **Total Fee**: Base fee × (multiplier/100)

3. **Fee Distribution**:
   - Base fee goes to the bridge adapter for the primary operation
   - Remaining fee (total fee - base fee) stays with the router to fund confirmations

### Fee Collection

1. The user sends `msg.value` to cover estimated fees
2. If `msg.value < totalFee`, the transaction reverts with `InsufficientFee`
3. If `msg.value > totalFee`, excess is refunded to the sender
4. Base fee is forwarded to the adapter; remainder stays with router

## Router Confirmations

### Confirmation Mechanism

1. **Trigger**: When `notifyTransferReceived()` is called on destination chain
2. **Confirmation Message**: Router attempts to send a confirmation back to the source chain:
   ```solidity
   bytes memory confirmationMessage = abi.encode(
       transferId,
       BridgeTypes.TransferStatus.DELIVERED
   );
   ```

3. **Confirmation Funding**:
   - Router uses accumulated funds (from fee multipliers) to pay for the confirmation
   - Confirmation doesn't apply another multiplier (would be redundant)

### Router Fund Management

1. **Source of Funds**:
   - Portion of fees via multiplier system
   - Direct funding via `addRouterFunds()` function (anyone can add funds)

2. **Fund Controls**:
   - Governance can withdraw via `removeRouterFunds()`
   - Check balance via `getRouterBalance()`

## Security Considerations

- **Adapter Registry**: Only governance can add/remove adapters
- **Pause Mechanism**: Both guardian and governance can pause; only governance can unpause
- **Status Progression**: Status can only move forward (PENDING → DELIVERED → COMPLETED)
- **Adapter Authentication**: Only registered adapters can call critical functions
- **Manual Recovery**: Governance/guardians can manually update status if automation fails
- **Reentrancy Protection**: Critical functions use ReentrancyGuard

## Integration Guide

To integrate with the bridge system:

1. **Sending assets cross-chain**:
   ```solidity
   function transferAssets(
       uint16 destinationChainId,
       address asset,
       uint256 amount,
       address recipient,
       BridgeTypes.BridgeOptions calldata options
   ) external payable returns (bytes32)
   ```

2. **Sending messages cross-chain**:
   ```solidity
   function sendMessage(
       uint16 destinationChainId,
       address recipient,
       bytes calldata message,
       BridgeTypes.BridgeOptions calldata options
   ) external payable returns (bytes32)
   ```

3. **Reading state from another chain**:
   ```solidity
   function readState(
       uint16 sourceChainId,
       address sourceContract,
       bytes4 selector,
       bytes calldata params,
       BridgeTypes.BridgeOptions calldata options
   ) external payable returns (bytes32)
   ```