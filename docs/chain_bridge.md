# ChainBridge Module - Technical Documentation

## 1. System Architecture

### 1.1 Overview
The ChainBridge Module enables secure cross-chain messaging and asset transfers for the Summer Protocol by providing a standardized interface to multiple third-party bridge providers. It abstracts away the complexities of different bridge implementations while creating a consistent interface for cross-chain operations.

### 1.2 Component Structure
The ChainBridge module consists of three primary components:

- **BridgeRouter**
  - Provides a unified entry point for all cross-chain operations
  - Routes messages between chains through appropriate bridge adapters
  - Manages adapter registration and selection
  - Tracks the status of cross-chain operations
  - Acts as the first receiver for all incoming cross-chain messages

- **BridgeAdapters**
  - Interface with specific third-party bridge protocols (LayerZero, Chainlink CCIP)
  - Translate between standardized message format and bridge-specific formats
  - Handle bridge-specific requirements for message passing
  - Implement provider-specific receiver interfaces for incoming messages
  - Provide fee estimation for their respective bridge providers

- **CrossChainReceivers**
  - Contracts that implement ICrossChainReceiver to receive cross-chain messages
  - Process incoming assets, messages, and data from other chains
  - May include specialized proxies for remote contracts (e.g., Ark Proxies)

### 1.3 Bridge Adapter System

```
flowchart TD
    A["Protocol Applications"] --> B["BridgeRouter"]
    B --> C["IBridgeAdapter"]
    C --> D1["LayerZeroAdapter"]
    C --> D2["ChainlinkAdapter"]
    C --> D3["Other Adapters..."]
    D1 --> E1["LayerZero Endpoint"]
    D2 --> E2["Chainlink CCIP Router"]
    D3 --> E3["Other Bridge Contracts"]
    E1 -.-> D1
    E2 -.-> D2
    E3 -.-> D3
    D1 & D2 & D3 -.-> B
    B -.-> F["ICrossChainReceiver"]
    F -.-> G1["OmniArk"]
    F -.-> G2["Ark Proxies"]
    F -.-> G3["Other Receivers"]
```

The adapter system enables:

- **Unified Message Format**: All applications use a consistent message format
- **Bridge Selection**: Choose different bridge providers based on cost, speed, or reliability
- **Provider Redundancy**: Fallback to alternative providers if primary option fails
- **Future Extensibility**: New bridge protocols can be added without changing core logic

### 1.4 Cross-Chain Messaging Flow

```
flowchart LR
    A["Source Application"] --> B["BridgeRouter (Source)"]
    B --> C["Bridge Adapter (Source)"]
    C --> D["Bridge Protocol"]
    D --> E["Cross-Chain Message"]
    E --> F["Bridge Protocol"]
    F --> G["Bridge Adapter (Destination)"]
    G --> H["BridgeRouter (Destination)"]
    H --> I["Cross-Chain Receiver"]
```

## 2. Cross-Chain Operations

### 2.1 Core Operations
The ChainBridge module supports three primary cross-chain operations:

1. **Asset Transfers**
   - Send assets from one chain to another
   - Destination receives assets via the `receiveAssets` function
   - Full tracking of transfer status throughout the process

2. **Message Passing**
   - Send arbitrary messages to contracts on other chains
   - Messages received via the `receiveMessage` function
   - Enables complex cross-chain operations beyond simple transfers

3. **State Reading**
   - Request state information from contracts on other chains
   - Results delivered asynchronously via `receiveStateRead` function
   - Allows cross-chain awareness without moving assets

### 2.2 Bridge Selection Process
The BridgeRouter implements a sophisticated selection process:

1. **Filter Available Adapters**
   - Identify adapters that support the source and destination chains
   - For asset transfers, check which adapters support the specific asset

2. **Get Fee Estimates**
   - Request fee estimates from each eligible adapter
   - Fees typically include gas costs on both chains and protocol fees

3. **Select Adapter**
   - Based on user preference (lowest cost, fastest, most reliable)
   - Apply default selection criteria if no preference specified

4. **Execute Operation**
   - Prepare message in standardized format
   - Pass to selected adapter for delivery to the destination chain

### 2.3 Bridge Adapters

#### LayerZero Adapter
- **Integration**: Interfaces with LayerZero endpoint
- **Message Format**: Converts standard messages to LayerZero format
- **Fee Structure**: Manages LayerZero's gas fees
- **Chains Supported**: All chains with LayerZero endpoints
- **Receiver Implementation**: Implements ILayerZeroReceiver for incoming messages

#### Chainlink Adapter
- **Integration**: Interfaces with Chainlink CCIP Router
- **Message Format**: Converts standard messages to CCIP format
- **Fee Structure**: Manages Chainlink's fee payments
- **Chains Supported**: All chains with CCIP router deployments
- **Receiver Implementation**: Implements CCIPReceiver for incoming messages

### 2.4 Adapter Interface
All bridge adapters implement the standardized IBridgeAdapter interface:

```solidity
interface IBridgeAdapter {
    // Core sending functions
    function transferAsset(
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        uint256 gasLimit,
        bytes calldata adapterParams
    ) external payable returns (bytes32 transferId);
    
    function estimateFee(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        uint256 gasLimit,
        bytes calldata adapterParams
    ) external view returns (uint256 nativeFee, uint256 tokenFee);
    
    // Status and capability functions
    function getTransferStatus(bytes32 transferId)
        external view returns (TransferStatus);
        
    function getSupportedChains() 
        external view returns (uint16[] memory);
        
    function getSupportedAssets(uint16 chainId)
        external view returns (address[] memory);
}
```

## 3. Receiver Model

### 3.1 ICrossChainReceiver Interface
Contracts that want to receive cross-chain messages implement the ICrossChainReceiver interface:

```solidity
interface ICrossChainReceiver {
    function receiveAssets(
        address asset,
        uint256 amount,
        address sender,
        uint16 sourceChainId,
        bytes32 transferId,
        bytes calldata extraData
    ) external;
    
    function receiveMessage(
        bytes calldata message,
        address sender,
        uint16 sourceChainId,
        bytes32 messageId
    ) external;
    
    function receiveStateRead(
        bytes calldata resultData,
        address requestor,
        uint16 sourceChainId,
        bytes32 requestId
    ) external;
}
```

### 3.2 Ark Proxy Model
For cross-chain OmniArk operations, we implement an Ark Proxy model:

1. **Deployment**: Each remote OmniArk is represented by a lightweight proxy on the destination chain
2. **Ownership**: The proxy owns assets and positions on behalf of the remote OmniArk
3. **Message Handling**: The proxy implements ICrossChainReceiver to handle instructions from its parent OmniArk
4. **Clean Accounting**: Provides clear ownership boundaries and simplified accounting for cross-chain assets

```
flowchart TD
    A["OmniArk (Chain A)"] -->|sends message| B["BridgeRouter (Chain A)"]
    B -->|bridges message| C["BridgeRouter (Chain B)"]
    C -->|routes message| D["Ark Proxy (Chain B)"]
    D -->|interacts with| E["Fleet (Chain B)"]
    D -->|owns positions in| E
```

## 4. Security Considerations

### 4.1 Security Model
The ChainBridge implements a layered security approach:

1. **Message Validation**
   - Each adapter validates incoming bridge messages
   - Provider-specific verification of message authenticity
   - Only registered adapters can update message status
   - BridgeRouter validates all incoming messages before forwarding

2. **Access Control**
   - Only the BridgeRouter can invoke certain adapter functions
   - Only registered adapters can deliver messages to receivers
   - Permissions are enforced at each layer of the stack

3. **Recovery Mechanisms**
   - Handles failed or incomplete transfers
   - Provides retry functionality for interrupted operations
   - Implements emergency pause capabilities

### 4.2 Bridge Provider Risks

Each bridge provider has its own security model and risks:

- **Consensus Risks**: Different bridges use different consensus mechanisms
- **Relayer Risks**: Some bridges rely on off-chain relayers
- **Smart Contract Risks**: Vulnerabilities in bridge contracts can affect messages
- **Network Risks**: Bridge performance depends on underlying network stability

The ChainBridge mitigates these through:
- Multiple bridge provider options
- Configurable message limits per bridge
- Careful monitoring of bridge status

## 5. Implementation Details

### 5.1 BridgeRouter Functions

```solidity
interface IBridgeRouter {
    function transferAsset(
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 transferId);
    
    function sendMessage(
        uint16 destinationChainId,
        address targetContract,
        bytes calldata message,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 messageId);
    
    function readState(
        uint16 sourceChainId,
        address sourceContract,
        bytes4 functionSelector, 
        bytes calldata params,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 readId);
    
    function estimateFee(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata options
    ) external view returns (uint256 nativeFee, uint256 tokenFee, address selectedAdapter);
    
    function getTransferStatus(bytes32 transferId)
        external view returns (BridgeTypes.TransferStatus);
        
    function registerAdapter(address adapter)
        external;
        
    function removeAdapter(address adapter)
        external;
}
```

### 5.2 Bridge Options

```solidity
struct BridgeOptions {
    address feeToken;           // Token to use for fees (address(0) for native)
    uint8 bridgePreference;     // 0: lowest cost, 1: fastest, 2: most secure
    uint256 gasLimit;           // Gas limit for execution on destination
    address refundAddress;      // Address to refund excess fees
    bytes adapterParams;        // Bridge-specific parameters
}
```

## 6. OmniArk Integration

### 6.1 Cross-Chain OmniArk Architecture

The OmniArk Cross-Chain architecture uses the ChainBridge to establish presence on multiple chains:

1. **Primary OmniArk**: User's main OmniArk on their home chain
2. **Ark Proxies**: Lightweight proxies on remote chains that:
   - Implement ICrossChainReceiver
   - Represent the OmniArk on that chain
   - Hold positions in the Fleet on behalf of the OmniArk
   - Execute instructions from the primary OmniArk

### 6.2 Cross-Chain Operations Flow

#### 6.2.1 Asset Transfer Flow (Chain A → Chain B)

```
flowchart LR
    A[CrossChainArk A] -->|1. transferCrossChain| B[BridgeRouter A]
    B -->|2. transferAssets| C[Selected Bridge Adapter A]
    C -->|3. bridge-specific transfer| D[Bridge Protocol]
    D -->|4. cross-chain message| E[Bridge Protocol]
    E -->|5. handleReceive| F[Bridge Adapter B]
    F -->|6. deliverAssets| G[BridgeRouter B]
    G -->|7. receiveAssets| H[CrossChainArkProxy B]
    H -->|8. deposit to Fleet/protocol| I[Fleet B]
```

1. **Initiation**: User calls `CrossChainArk.transferCrossChain()` on Chain A
2. **Router Handling**: BridgeRouter selects appropriate adapter and forwards assets
3. **Bridge Transfer**: Bridge adapter formats the message and initiates cross-chain transfer
4. **Destination Receipt**: Bridge adapter on Chain B receives the message
5. **Asset Delivery**: Assets are delivered to the CrossChainArkProxy on Chain B
6. **Position Management**: CrossChainArkProxy deposits assets into Fleet/protocol on Chain B

#### 6.2.2 Asset Withdrawal Flow (Chain B → Chain A)

```
flowchart LR
    A[CrossChainArk A] -->|1. withdrawCrossChain| B[BridgeRouter A]
    B -->|2. sendMessage| C[Bridge Adapter A]
    C -->|3. bridge-specific message| D[Bridge Protocol]
    D -->|4. cross-chain message| E[Bridge Protocol]
    E -->|5. handleReceive| F[Bridge Adapter B]
    F -->|6. deliverMessage| G[BridgeRouter B]
    G -->|7. receiveMessage| H[CrossChainArkProxy B]
    H -->|8. withdraw from Fleet| I[Fleet B]
    H -->|9. transferCrossChain| J[BridgeRouter B]
    J -->|10. transferAssets| K[Bridge Adapter B]
    K -->|11. bridge-specific transfer| L[Bridge Protocol]
    L -->|12. cross-chain asset| M[Bridge Protocol]
    M -->|13. handleReceive| N[Bridge Adapter A]
    N -->|14. deliverAssets| O[BridgeRouter A]
    O -->|15. receiveAssets| P[CrossChainArk A]
```

1. **Initiation**: User requests withdrawal via `CrossChainArk.withdrawCrossChain()` on Chain A
2. **Withdrawal Message**: BridgeRouter A sends a message to Chain B with withdrawal instructions
3. **Proxy Execution**: CrossChainArkProxy receives message and withdraws from Fleet on Chain B
4. **Return Transfer**: CrossChainArkProxy initiates transfer back to the original CrossChainArk
5. **Asset Return**: Assets are transferred back to the CrossChainArk on Chain A

#### 6.2.3 Cross-Chain State Reading (Total Assets Update)

```
flowchart LR
    A[CrossChainArk A] -->|1. readCrossChainState| B[BridgeRouter A]
    B -->|2. readState| C[Bridge Adapter A]
    C -->|3. bridge-specific query| D[Bridge Protocol]
    D -->|4. cross-chain message| E[Bridge Protocol]
    E -->|5. handleReceive| F[Bridge Adapter B]
    F -->|6. executeRead| G[BridgeRouter B]
    G -->|7. query assets| H[CrossChainArkProxy B]
    H -->|8. query positions| I[Fleet B]
    I -->|9. position data| H
    H -->|10. format response| G
    G -->|11. return data| F
    F -->|12. bridge-specific response| E
    E -->|13. cross-chain message| D
    D -->|14. handleReceive| C
    C -->|15. deliverReadResponse| B
    B -->|16. receiveStateRead| A
    A -->|17. update total assets view| A
```

1. **Query Initiation**: CrossChainArk on Chain A requests state information via `readCrossChainState()`
2. **Query Routing**: BridgeRouter sends read request to Chain B via appropriate adapter
3. **Data Collection**: On Chain B, CrossChainArkProxy queries its positions in Fleet B
4. **Response Construction**: CrossChainArkProxy formats the response data
5. **Response Delivery**: Data is sent back to Chain A through the bridge
6. **Data Integration**: CrossChainArk receives position data and updates its total assets view
7. **User Visibility**: User now has a complete view of assets across all chains

### 6.3 Cross-Chain Operations Examples

#### Asset Transfer Example
```solidity
// On Chain A - User initiates cross-chain deposit
function transferToChainB(address asset, uint256 amount) external {
    // Transfer assets to another chain
    CrossChainArk(myArk).transferCrossChain(
        CHAIN_B_ID,
        asset, 
        amount,
        BridgeOptions({
            bridgePreference: LOWEST_COST,
            gasLimit: 300000,
            // other options...
        })
    );
}

// On Chain B - ArkProxy receives assets and deposits to Fleet
function receiveAssets(
    address asset,
    uint256 amount,
    address sender,
    uint16 sourceChainId,
    bytes32 transferId,
    bytes calldata depositData
) external override onlyBridgeRouter {
    // Verify sender is the crosschain relationship
    require(sender == registeredSourceArk, "Invalid sender");
    
    // Decode deposit instructions
    (address fleet, uint256 depositAmount) = abi.decode(depositData, (address, uint256));
    
    // Approve and deposit to Fleet
    IERC20(asset).approve(fleet, depositAmount);
    IFleetCommander(fleet).deposit(depositAmount, address(this), "");
    
    emit AssetsReceived(asset, amount, sender, sourceChainId, transferId);
}
```

#### Asset Withdrawal Example
```solidity
// On Chain A - User initiates withdrawal from Chain B
function withdrawFromChainB(address asset, uint256 shares) external {
    // Request withdrawal from Chain B
    CrossChainArk(myArk).withdrawCrossChain(
        CHAIN_B_ID,
        asset,
        shares,
        BridgeOptions({
            bridgePreference: LOWEST_COST,
            gasLimit: 500000,
            // other options...
        })
    );
}

// On Chain B - ArkProxy receives withdrawal request
function receiveMessage(
    bytes calldata message,
    address sender,
    uint16 sourceChainId,
    bytes32 messageId
) external override onlyBridgeRouter {
    // Verify sender is the crosschain relationship
    require(sender == registeredSourceArk, "Invalid sender");
    
    // Decode withdrawal instructions
    (bytes32 action, address fleet, address asset, uint256 shares) = 
        abi.decode(message, (bytes32, address, address, uint256));
    
    if (action == WITHDRAW_ACTION) {
        // Withdraw from Fleet
        uint256 assets = IFleetCommander(fleet).redeem(shares, address(this), address(this));
        
        // Send assets back to Chain A
        IBridgeRouter(bridgeRouter).transferAssets(
            sourceChainId,
            asset,
            assets,
            sender,
            BridgeOptions({
                bridgePreference: LOWEST_COST,
                gasLimit: 300000,
                // other options...
            })
        );
        
        emit WithdrawalProcessed(asset, assets, messageId);
    }
}
```

#### Cross-Chain State Reading Example
```solidity
// On Chain A - Request total assets information from Chain B
function getTotalAssetsOnChainB() external {
    CrossChainArk(myArk).readCrossChainState(
        CHAIN_B_ID,
        arkProxyAddress,
        this.getTotalAssets.selector,
        "",
        BridgeOptions({
            bridgePreference: LOWEST_COST,
            gasLimit: 200000,
            // other options...
        })
    );
}

// On Chain B - ArkProxy responds with total assets data
function getTotalAssets() external view returns (address[] memory assets, uint256[] memory amounts) {
    // Get list of all managed assets
    assets = managedAssets();
    amounts = new uint256[](assets.length);
    
    // For each asset, get total across all Fleets
    for (uint i = 0; i < assets.length; i++) {
        for (uint j = 0; j < fleets.length; j++) {
            // Add assets from each Fleet
            amounts[i] += IFleetCommander(fleets[j]).previewRedeem(
                IFleetCommander(fleets[j]).balanceOf(address(this))
            );
        }
        
        // Add any undeployed balance
        amounts[i] += IERC20(assets[i]).balanceOf(address(this));
    }
    
    return (assets, amounts);
}

// On Chain A - CrossChainArk receives and processes the state data
function receiveStateRead(
    bytes calldata resultData,
    address requestor,
    uint16 sourceChainId,
    bytes32 requestId
) external override onlyBridgeRouter {
    // Decode assets data
    (address[] memory assets, uint256[] memory amounts) = 
        abi.decode(resultData, (address[], uint256[]));
    
    // Update internal accounting for cross-chain assets
    for (uint i = 0; i < assets.length; i++) {
        crossChainAssetBalances[sourceChainId][assets[i]] = amounts[i];
    }
    
    emit CrossChainAssetsUpdated(sourceChainId, assets, amounts);
    
    // If original requestor is waiting, notify them
    if (pendingQueries[requestId] != address(0)) {
        ICrossChainQueryCallback(pendingQueries[requestId]).onCrossChainDataReceived(
            requestId, 
            sourceChainId, 
            resultData
        );
        delete pendingQueries[requestId];
    }
}
```

### 6.4 Security Model

The cross-chain OmniArk architecture implements a robust security model:

1. **Message Authentication**: All messages between OmniArk and proxies are authenticated
2. **Limited Scope**: Each Ark Proxy can only interact with specific contracts
3. **Recovery Path**: Primary OmniArk can recover assets if a bridge fails
4. **Gradual Migration**: OmniArks can migrate between chains if needed
5. **Trust Minimization**: Cross-chain operations require minimal trust in bridge providers through:
   - Multiple bridge fallback options
   - Verification of received assets 
   - Clear accounting of cross-chain positions

## 7. Future Extensions

### 7.1 Planned Enhancements

1. **Additional Bridge Providers**: Support for more bridge protocols
2. **Advanced Routing**: Smart routing across multiple bridges for optimal paths
3. **Risk Management**: Automated risk assessment and bridge selection
4. **Cross-Chain Governance**: Enable governance actions across chains
5. **Bridge Analytics**: Real-time monitoring and performance metrics

### 7.2 Integration Opportunities

1. **Cross-Chain Strategies**: Enable strategies that operate across multiple chains
2. **Fleet Interconnection**: Allow Fleets on different chains to coordinate
3. **Cross-Chain Liquidity**: Enable assets to flow efficiently between chains
4. **Protocol-Wide Visibility**: Unified view of user positions across all chains