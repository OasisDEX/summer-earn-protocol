# Class: DebtInfo

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts#L23)

DebtInfo

## See

IDebtInfo

For now this class can be re-used among all the protocols and there is no need for specialization

## Implements

- [`IDebtInfo`](../interfaces/IDebtInfo.md)

## Constructors

### Constructor

```ts
protected new DebtInfo(params): DebtInfo;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts:44](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts#L44)

CONSTRUCTOR

#### Parameters

##### params

[`DebtInfoParameters`](../type-aliases/DebtInfoParameters.md)

#### Returns

`DebtInfo`

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts#L25)

SIGNATURE

#### Implementation of

[`IDebtInfo`](../interfaces/IDebtInfo.md).[`[___signature__]`](../interfaces/IDebtInfo.md#___signature__)

***

### debtAvailable

```ts
readonly debtAvailable: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts:34](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts#L34)

The amount of the token that can still be borrowed

#### Implementation of

[`IDebtInfo`](../interfaces/IDebtInfo.md).[`debtAvailable`](../interfaces/IDebtInfo.md#debtavailable)

***

### debtCeiling

```ts
readonly debtCeiling: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts#L33)

The maximum amount of the token that can be borrowed

#### Implementation of

[`IDebtInfo`](../interfaces/IDebtInfo.md).[`debtCeiling`](../interfaces/IDebtInfo.md#debtceiling)

***

### dustLimit

```ts
readonly dustLimit: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts:35](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts#L35)

The minimum amount of the token that can be borrowed

#### Implementation of

[`IDebtInfo`](../interfaces/IDebtInfo.md).[`dustLimit`](../interfaces/IDebtInfo.md#dustlimit)

***

### interestRate

```ts
readonly interestRate: IPercentage;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts#L31)

The interest rate of the debt. TODO: which units??

#### Implementation of

[`IDebtInfo`](../interfaces/IDebtInfo.md).[`interestRate`](../interfaces/IDebtInfo.md#interestrate)

***

### originationFee

```ts
readonly originationFee: IPercentage;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts:36](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts#L36)

The fee that is charged for creating a new debt

#### Implementation of

[`IDebtInfo`](../interfaces/IDebtInfo.md).[`originationFee`](../interfaces/IDebtInfo.md#originationfee)

***

### price

```ts
readonly price: IPrice;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts#L29)

The price of the token in the protocol's default denomination

#### Implementation of

[`IDebtInfo`](../interfaces/IDebtInfo.md).[`price`](../interfaces/IDebtInfo.md#price)

***

### priceUSD

```ts
readonly priceUSD: IPrice;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts#L30)

The price of the token in USD

#### Implementation of

[`IDebtInfo`](../interfaces/IDebtInfo.md).[`priceUSD`](../interfaces/IDebtInfo.md#priceusd)

***

### token

```ts
readonly token: ITokenStanalone;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts#L28)

ATTRIBUTES

#### Implementation of

[`IDebtInfo`](../interfaces/IDebtInfo.md).[`token`](../interfaces/IDebtInfo.md#token)

***

### totalBorrowed

```ts
readonly totalBorrowed: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts#L32)

The total amount of the token borrowed

#### Implementation of

[`IDebtInfo`](../interfaces/IDebtInfo.md).[`totalBorrowed`](../interfaces/IDebtInfo.md#totalborrowed)

## Methods

### createFrom()

```ts
static createFrom(params): DebtInfo;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts:39](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/DebtInfo.ts#L39)

FACTORY METHODS

#### Parameters

##### params

[`DebtInfoParameters`](../type-aliases/DebtInfoParameters.md)

#### Returns

`DebtInfo`
