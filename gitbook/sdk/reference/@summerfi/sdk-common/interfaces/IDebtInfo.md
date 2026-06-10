# Interface: IDebtInfo

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts#L19)

IDebtInfo

## Description

Contains information about a debt token of a lending pool

Initially this is used for single pair lending pools, but it can be re-used in multi-token
lending pools

## Extends

- [`IDebtInfoData`](../type-aliases/IDebtInfoData.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts#L21)

Signature to differentiate from similar interfaces

***

### debtAvailable

```ts
readonly debtAvailable: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts:35](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts#L35)

The amount of the token that can still be borrowed

#### Overrides

```ts
IDebtInfoData.debtAvailable
```

***

### debtCeiling

```ts
readonly debtCeiling: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts#L33)

The maximum amount of the token that can be borrowed

#### Overrides

```ts
IDebtInfoData.debtCeiling
```

***

### dustLimit

```ts
readonly dustLimit: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts:37](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts#L37)

The minimum amount of the token that can be borrowed

#### Overrides

```ts
IDebtInfoData.dustLimit
```

***

### interestRate

```ts
readonly interestRate: IPercentage;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts#L29)

The interest rate of the debt. TODO: which units??

#### Overrides

```ts
IDebtInfoData.interestRate
```

***

### originationFee

```ts
readonly originationFee: IPercentage;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts:39](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts#L39)

The fee that is charged for creating a new debt

#### Overrides

```ts
IDebtInfoData.originationFee
```

***

### price

```ts
readonly price: IPrice;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts#L25)

The price of the token in the protocol's default denomination

#### Overrides

```ts
IDebtInfoData.price
```

***

### priceUSD

```ts
readonly priceUSD: IPrice;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts#L27)

The price of the token in USD

#### Overrides

```ts
IDebtInfoData.priceUSD
```

***

### token

```ts
readonly token: ITokenStanalone;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts#L23)

The token that represents the debt

#### Overrides

```ts
IDebtInfoData.token
```

***

### totalBorrowed

```ts
readonly totalBorrowed: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts#L31)

The total amount of the token borrowed

#### Overrides

```ts
IDebtInfoData.totalBorrowed
```
