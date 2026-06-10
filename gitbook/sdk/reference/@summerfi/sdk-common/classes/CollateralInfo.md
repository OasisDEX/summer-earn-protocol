# Class: CollateralInfo

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts#L23)

CollateralInfo

## See

ICollateralInfo

## Implements

- [`ICollateralInfo`](../interfaces/ICollateralInfo.md)

## Constructors

### Constructor

```ts
protected new CollateralInfo(params): CollateralInfo;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts:43](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts#L43)

CONSTRUCTOR

#### Parameters

##### params

[`CollateralInfoParameters`](../type-aliases/CollateralInfoParameters.md)

#### Returns

`CollateralInfo`

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts#L25)

SIGNATURE

#### Implementation of

[`ICollateralInfo`](../interfaces/ICollateralInfo.md).[`[___signature__]`](../interfaces/ICollateralInfo.md#___signature__)

***

### liquidationPenalty

```ts
readonly liquidationPenalty: IPercentage;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts:34](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts#L34)

The penalty that is charged for liquidating a position

#### Implementation of

[`ICollateralInfo`](../interfaces/ICollateralInfo.md).[`liquidationPenalty`](../interfaces/ICollateralInfo.md#liquidationpenalty)

***

### liquidationThreshold

```ts
readonly liquidationThreshold: IRiskRatio;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts#L31)

The ratio between the collateral and the debt at which the position could be liquidated

#### Implementation of

[`ICollateralInfo`](../interfaces/ICollateralInfo.md).[`liquidationThreshold`](../interfaces/ICollateralInfo.md#liquidationthreshold)

***

### maxSupply

```ts
readonly maxSupply: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts#L32)

The maximum amount of the token that can be supplied

#### Implementation of

[`ICollateralInfo`](../interfaces/ICollateralInfo.md).[`maxSupply`](../interfaces/ICollateralInfo.md#maxsupply)

***

### price

```ts
readonly price: IPrice;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts#L29)

The price of the token in the protocol's default denomination

#### Implementation of

[`ICollateralInfo`](../interfaces/ICollateralInfo.md).[`price`](../interfaces/ICollateralInfo.md#price)

***

### priceUSD

```ts
readonly priceUSD: IPrice;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts#L30)

The price of the token in USD

#### Implementation of

[`ICollateralInfo`](../interfaces/ICollateralInfo.md).[`priceUSD`](../interfaces/ICollateralInfo.md#priceusd)

***

### token

```ts
readonly token: ITokenStanalone;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts#L28)

ATTRIBUTES

#### Implementation of

[`ICollateralInfo`](../interfaces/ICollateralInfo.md).[`token`](../interfaces/ICollateralInfo.md#token)

***

### tokensLocked

```ts
readonly tokensLocked: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts#L33)

The amount of the token that is currently locked in the pool

#### Implementation of

[`ICollateralInfo`](../interfaces/ICollateralInfo.md).[`tokensLocked`](../interfaces/ICollateralInfo.md#tokenslocked)

## Methods

### createFrom()

```ts
static createFrom(params): CollateralInfo;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts:38](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/CollateralInfo.ts#L38)

FACTORY METHODS

#### Parameters

##### params

[`CollateralInfoParameters`](../type-aliases/CollateralInfoParameters.md)

#### Returns

`CollateralInfo`
