# Interface: IRebalanceData

Defined in: [sdk/sdk-common/src/common/types/IRebalanceData.ts:12](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/types/IRebalanceData.ts#L12)

## Name

IRebalanceData

## Description

Data structure for rebalancing assets, used by Keepers of a fleet

## Properties

### amount

```ts
readonly amount: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/types/IRebalanceData.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/types/IRebalanceData.ts#L19)

Amount of tokens to be moved

***

### boardData?

```ts
readonly optional boardData: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/types/IRebalanceData.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/types/IRebalanceData.ts#L21)

Board data

***

### disembarkData?

```ts
readonly optional disembarkData: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/types/IRebalanceData.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/types/IRebalanceData.ts#L23)

Disembark data

***

### fromArk

```ts
readonly fromArk: IAddress;
```

Defined in: [sdk/sdk-common/src/common/types/IRebalanceData.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/types/IRebalanceData.ts#L15)

Ark where the tokens are taken from

***

### toArk

```ts
readonly toArk: IAddress;
```

Defined in: [sdk/sdk-common/src/common/types/IRebalanceData.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/types/IRebalanceData.ts#L17)

Ark where the tokens are moved to
