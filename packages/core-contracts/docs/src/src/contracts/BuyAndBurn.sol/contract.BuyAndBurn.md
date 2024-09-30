# BuyAndBurn
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/contracts/BuyAndBurn.sol)

**Inherits:**
[IBuyAndBurn](/src/interfaces/IBuyAndBurn.sol/interface.IBuyAndBurn.md), [ProtocolAccessManaged](/src/contracts/ProtocolAccessManaged.sol/contract.ProtocolAccessManaged.md), [AuctionManagerBase](/src/contracts/AuctionManagerBase.sol/abstract.AuctionManagerBase.md)

This contract manages auctions for tokens, accepting SUMMER tokens as payment and burning them.

*Inherits from IBuyAndBurn, ProtocolAccessManaged, and AuctionManagerBase to handle auctions and access control.*


## State Variables
### summerToken

```solidity
ERC20Burnable public immutable summerToken;
```


### manager

```solidity
IConfigurationManager public manager;
```


### auctions
Mapping of auction IDs to their respective auction data


```solidity
mapping(uint256 auctionId => DutchAuctionLibrary.Auction auction) public auctions;
```


### ongoingAuctions
Mapping of token addresses to their ongoing auction IDs (0 if no ongoing auction)


```solidity
mapping(address tokenAddress => uint256 auctionId) public ongoingAuctions;
```


### auctionSummerRaised
Mapping of auction IDs to the amount of SUMMER tokens raised in that auction


```solidity
mapping(uint256 auctionId => uint256 amountRaised) public auctionSummerRaised;
```


## Functions
### constructor


```solidity
constructor(
    address _summer,
    address _accessManager,
    address _configurationManager,
    AuctionDefaultParameters memory _defaultParameters
)
    ProtocolAccessManaged(_accessManager)
    AuctionManagerBase(_defaultParameters);
```

### startAuction


```solidity
function startAuction(address tokenToAuction) external override onlyGovernor;
```

### buyTokens


```solidity
function buyTokens(uint256 auctionId, uint256 amount) external override returns (uint256 summerAmount);
```

### finalizeAuction


```solidity
function finalizeAuction(uint256 auctionId) external override onlyGovernor;
```

### getAuctionInfo


```solidity
function getAuctionInfo(uint256 auctionId) external view override returns (DutchAuctionLibrary.Auction memory);
```

### getCurrentPrice


```solidity
function getCurrentPrice(uint256 auctionId) external view returns (uint256);
```

### updateAuctionDefaultParameters


```solidity
function updateAuctionDefaultParameters(AuctionDefaultParameters calldata newParameters)
    external
    override
    onlyGovernor;
```

### _settleAuction

Settles an auction by burning the raised SUMMER tokens and cleaning up state


```solidity
function _settleAuction(DutchAuctionLibrary.Auction memory auction) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auction`|`DutchAuctionLibrary.Auction`|The auction to settle|


