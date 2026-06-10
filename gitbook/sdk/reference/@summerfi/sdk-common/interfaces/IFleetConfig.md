# Interface: IFleetConfig

Defined in: [sdk/sdk-common/src/common/types/IFleetConfig.ts:8](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/types/IFleetConfig.ts#L8)

## Name

IFleetConfig

## Description

Data structure for rebalancing assets, used by Keepers of a fleet

## Properties

### bufferArk

```ts
readonly bufferArk: IAddress;
```

Defined in: [sdk/sdk-common/src/common/types/IFleetConfig.ts:10](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/types/IFleetConfig.ts#L10)

The address of the buffer Ark associated with this Fleet

***

### depositCap

```ts
readonly depositCap: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/types/IFleetConfig.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/types/IFleetConfig.ts#L14)

The maximum total value of assets that can be deposited into the fleet

***

### maxRebalanceOperations

```ts
readonly maxRebalanceOperations: string;
```

Defined in: [sdk/sdk-common/src/common/types/IFleetConfig.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/types/IFleetConfig.ts#L16)

The maximum number of rebalance operations that can be performed in a single rebalance transaction

***

### minimumBufferBalance

```ts
readonly minimumBufferBalance: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/types/IFleetConfig.ts:12](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/types/IFleetConfig.ts#L12)

The minimum balance that should be maintained in the buffer Ark

***

### stakingRewardsManager

```ts
readonly stakingRewardsManager: IAddress;
```

Defined in: [sdk/sdk-common/src/common/types/IFleetConfig.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/types/IFleetConfig.ts#L18)

The address of the staking rewards manager contract
