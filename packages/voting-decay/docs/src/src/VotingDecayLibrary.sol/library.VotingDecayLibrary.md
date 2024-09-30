# VotingDecayLibrary
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/c6aec955808af03c05b24342f892f71facee60db/src/VotingDecayLibrary.sol)


## State Variables
### WAD

```solidity
uint256 public constant WAD = 1e18;
```


### SECONDS_PER_YEAR

```solidity
uint256 private constant SECONDS_PER_YEAR = 365 days;
```


## Functions
### calculateDecayFactor


```solidity
function calculateDecayFactor(
    uint256 currentDecayFactor,
    uint256 elapsedSeconds,
    uint256 decayRatePerSecond,
    uint256 decayFreeWindow,
    DecayFunction decayFunction
)
    internal
    pure
    returns (uint256);
```

### applyDecay


```solidity
function applyDecay(uint256 originalValue, uint256 retentionFactor) internal pure returns (uint256);
```

### isValidDecayRate


```solidity
function isValidDecayRate(uint256 rate) internal pure returns (bool);
```

## Errors
### InvalidDecayType
Thrown when the decay type is invalid


```solidity
error InvalidDecayType();
```

## Structs
### DecayInfo

```solidity
struct DecayInfo {
    uint256 decayFactor;
    uint40 lastUpdateTimestamp;
}
```

## Enums
### DecayFunction

```solidity
enum DecayFunction {
    Linear,
    Exponential
}
```

