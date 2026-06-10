# Interface: ICollateralInfo

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts#L17)

ICollateralInfo

## Description

Contains extended information about a collateral token of a lending pool

## Extends

- [`ICollateralInfoData`](../type-aliases/ICollateralInfoData.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts#L19)

Signature to differentiate from similar interfaces

***

### liquidationPenalty

```ts
readonly liquidationPenalty: IPercentage;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts#L33)

The penalty that is charged for liquidating a position

#### Overrides

```ts
ICollateralInfoData.liquidationPenalty
```

***

### liquidationThreshold

```ts
readonly liquidationThreshold: IRiskRatio;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts#L27)

The ratio between the collateral and the debt at which the position could be liquidated

#### Overrides

```ts
ICollateralInfoData.liquidationThreshold
```

***

### maxSupply

```ts
readonly maxSupply: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts#L29)

The maximum amount of the token that can be supplied

#### Overrides

```ts
ICollateralInfoData.maxSupply
```

***

### price

```ts
readonly price: IPrice;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts#L23)

The price of the token in the protocol's default denomination

#### Overrides

```ts
ICollateralInfoData.price
```

***

### priceUSD

```ts
readonly priceUSD: IPrice;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts#L25)

The price of the token in USD

#### Overrides

```ts
ICollateralInfoData.priceUSD
```

***

### token

```ts
readonly token: ITokenStanalone;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts#L21)

The token that represents the collateral

#### Overrides

```ts
ICollateralInfoData.token
```

***

### tokensLocked

```ts
readonly tokensLocked: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts#L31)

The amount of the token that is currently locked in the pool

#### Overrides

```ts
ICollateralInfoData.tokensLocked
```
