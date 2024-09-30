# Raft
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/contracts/Raft.sol)

**Inherits:**
[IRaft](/src/interfaces/IRaft.sol/interface.IRaft.md), [ArkAccessManaged](/src/contracts/ArkAccessManaged.sol/contract.ArkAccessManaged.md), [AuctionManagerBase](/src/contracts/AuctionManagerBase.sol/abstract.AuctionManagerBase.md)

This contract manages the harvesting of rewards from Arks and conducts Dutch auctions for the reward tokens.

*Inherits from IRaft, ArkAccessManaged, and AuctionManagerBase to handle access control and auction mechanics.*


## State Variables
### obtainedTokens
Mapping of harvested rewards for each Ark and reward token


```solidity
mapping(address ark => mapping(address rewardToken => uint256 harvestedAmount)) public obtainedTokens;
```


### auctions
Mapping of ongoing auctions for each Ark and reward token


```solidity
mapping(address ark => mapping(address rewardToken => DutchAuctionLibrary.Auction)) public auctions;
```


### unsoldTokens
Mapping of unsold tokens for each Ark and reward token


```solidity
mapping(address ark => mapping(address rewardToken => uint256 remainingTokens)) public unsoldTokens;
```


### paymentTokensToBoard
Mapping of payment tokens boarded to each Ark and reward token


```solidity
mapping(address ark => mapping(address rewardToken => uint256 paymentTokensToBoard)) public paymentTokensToBoard;
```


## Functions
### constructor


```solidity
constructor(
    address _accessManager,
    AuctionDefaultParameters memory defaultParameters
)
    ArkAccessManaged(_accessManager)
    AuctionManagerBase(defaultParameters);
```

### harvestAndStartAuction


```solidity
function harvestAndStartAuction(address ark, address paymentToken, bytes calldata rewardData) external onlyGovernor;
```

### sweepAndStartAuction


```solidity
function sweepAndStartAuction(address ark, address[] calldata tokens, address paymentToken) external onlyGovernor;
```

### startAuction


```solidity
function startAuction(address ark, address rewardToken, address paymentToken) public onlyGovernor;
```

### harvest


```solidity
function harvest(address ark, bytes calldata rewardData) public;
```

### sweep


```solidity
function sweep(
    address ark,
    address[] calldata tokens
)
    external
    onlyGovernor
    returns (address[] memory sweptTokens, uint256[] memory sweptAmounts);
```

### _sweep


```solidity
function _sweep(
    address ark,
    address[] calldata tokens
)
    internal
    onlyGovernor
    returns (address[] memory sweptTokens, uint256[] memory sweptAmounts);
```

### buyTokens


```solidity
function buyTokens(address ark, address rewardToken, uint256 amount) external returns (uint256 paymentAmount);
```

### finalizeAuction


```solidity
function finalizeAuction(address ark, address rewardToken) external;
```

### getAuctionInfo


```solidity
function getAuctionInfo(address ark, address rewardToken) external view returns (DutchAuctionLibrary.Auction memory);
```

### getCurrentPrice


```solidity
function getCurrentPrice(address ark, address rewardToken) external view returns (uint256);
```

### updateAuctionDefaultParameters


```solidity
function updateAuctionDefaultParameters(AuctionDefaultParameters calldata newConfig) external onlyGovernor;
```

### getObtainedTokens


```solidity
function getObtainedTokens(address ark, address rewardToken) external view returns (uint256);
```

### _harvest


```solidity
function _harvest(
    address ark,
    bytes calldata rewardData
)
    internal
    returns (address[] memory harvestedTokens, uint256[] memory harvestedAmounts);
```

### _startAuction


```solidity
function _startAuction(address ark, address rewardToken, address paymentToken) internal;
```

### board


```solidity
function board(address ark, address rewardToken, bytes calldata data) external onlyGovernor;
```

### _settleAuction

*Settles the auction by handling unsold tokens*


```solidity
function _settleAuction(address ark, address rewardToken, DutchAuctionLibrary.Auction memory auction) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark|
|`rewardToken`|`address`|The address of the reward token|
|`auction`|`DutchAuctionLibrary.Auction`|The auction to be settled|


### _board

*Boards the payment tokens to the Ark*


```solidity
function _board(address rewardToken, address ark, bytes memory data) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardToken`|`address`|The address of the reward token|
|`ark`|`address`|The address of the Ark|
|`data`|`bytes`|The data to be passed to the Ark|


