# Class: PositionUtils

Defined in: [sdk/sdk-client/src/utils/PositionUtils.ts:7](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/utils/PositionUtils.ts#L7)

## Constructors

### Constructor

```ts
new PositionUtils(): PositionUtils;
```

#### Returns

`PositionUtils`

## Methods

### getLiquidationPriceInDebtTokens()

```ts
static getLiquidationPriceInDebtTokens(__namedParameters): string;
```

Defined in: [sdk/sdk-client/src/utils/PositionUtils.ts:35](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/utils/PositionUtils.ts#L35)

This code calculates the value of one collateral token expressed in debt tokens at which the loan-to-value (LTV) ratio will be at liquidationThreshold

#### Parameters

##### \_\_namedParameters

###### debtPriceInUsd

`string`

###### liquidationThreshold

[`Percentage`](Percentage.md)

###### position

[`ILendingPosition`](../interfaces/ILendingPosition.md)

#### Returns

`string`

***

### getLTV()

```ts
static getLTV(__namedParameters): IPercentage;
```

Defined in: [sdk/sdk-client/src/utils/PositionUtils.ts:8](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/utils/PositionUtils.ts#L8)

#### Parameters

##### \_\_namedParameters

###### collateralPriceInUsd

`string`

###### collateralTokenAmount

[`ITokenAmount`](../interfaces/ITokenAmount.md)

###### debtPriceInUsd

`string`

###### debtTokenAmount

[`ITokenAmount`](../interfaces/ITokenAmount.md)

#### Returns

[`IPercentage`](../interfaces/IPercentage.md)
