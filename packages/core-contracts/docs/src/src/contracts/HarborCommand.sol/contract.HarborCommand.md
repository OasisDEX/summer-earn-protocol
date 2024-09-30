# HarborCommand
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/contracts/HarborCommand.sol)

**Inherits:**
[ProtocolAccessManaged](/src/contracts/ProtocolAccessManaged.sol/contract.ProtocolAccessManaged.md), [IHarborCommandEvents](/src/events/IHarborCommandEvents.sol/interface.IHarborCommandEvents.md), [IHarborCommand](/src/interfaces/IHarborCommand.sol/interface.IHarborCommand.md)


## State Variables
### activeFleetCommanders

```solidity
mapping(address => bool) public activeFleetCommanders;
```


### fleetCommandersList

```solidity
address[] public fleetCommandersList;
```


## Functions
### constructor


```solidity
constructor(address _accessManager) ProtocolAccessManaged(_accessManager);
```

### enlistFleetCommander


```solidity
function enlistFleetCommander(address _fleetCommander) external onlyGovernor;
```

### decommissionFleetCommander


```solidity
function decommissionFleetCommander(address _fleetCommander) external onlyGovernor;
```

### getActiveFleetCommanders


```solidity
function getActiveFleetCommanders() external view returns (address[] memory);
```

