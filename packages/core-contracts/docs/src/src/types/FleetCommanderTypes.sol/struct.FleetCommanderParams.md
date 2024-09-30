# FleetCommanderParams
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/types/FleetCommanderTypes.sol)

Configuration parameters for the FleetCommander contract


```solidity
struct FleetCommanderParams {
    string name;
    string symbol;
    address[] initialArks;
    address configurationManager;
    address accessManager;
    address asset;
    address bufferArk;
    uint256 initialMinimumBufferBalance;
    uint256 initialRebalanceCooldown;
    uint256 depositCap;
    Percentage initialTipRate;
}
```

