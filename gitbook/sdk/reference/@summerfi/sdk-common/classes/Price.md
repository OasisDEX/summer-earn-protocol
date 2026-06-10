# Class: Price

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:37](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L37)

Price

## See

IPrice

## Implements

- [`IPrice`](../interfaces/IPrice.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:39](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L39)

SIGNATURE

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`[___signature__]`](../interfaces/IPrice.md#___signature__)

***

### base

```ts
readonly base: Denomination;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:46](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L46)

The token for the base of the price

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`base`](../interfaces/IPrice.md#base)

***

### quote

```ts
readonly quote: Denomination;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:47](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L47)

The token for the quote of the price

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`quote`](../interfaces/IPrice.md#quote)

***

### value

```ts
readonly value: string;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:45](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L45)

ATTRIBUTES

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`value`](../interfaces/IPrice.md#value)

***

### PRICE\_DECIMALS

```ts
readonly static PRICE_DECIMALS: 18 = 18;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:42](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L42)

CONSTANTS

## Methods

### add()

```ts
add(otherPrice): IPrice;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:136](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L136)

#### Parameters

##### otherPrice

[`IPrice`](../interfaces/IPrice.md)

#### Returns

[`IPrice`](../interfaces/IPrice.md)

#### See

IPrice.add

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`add`](../interfaces/IPrice.md#add)

***

### divide()

```ts
divide(divider): IPrice;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:191](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L191)

#### Parameters

##### divider

`string` | `number` | [`IPercentage`](../interfaces/IPercentage.md) | [`IPrice`](../interfaces/IPrice.md)

#### Returns

[`IPrice`](../interfaces/IPrice.md)

#### See

IPrice.divide

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`divide`](../interfaces/IPrice.md#divide)

***

### hasSameBase()

```ts
hasSameBase(otherPrice): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:122](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L122)

#### Parameters

##### otherPrice

[`IPrice`](../interfaces/IPrice.md)

#### Returns

`boolean`

#### See

IPrice.hasSameBase

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`hasSameBase`](../interfaces/IPrice.md#hassamebase)

***

### hasSameDenominations()

```ts
hasSameDenominations(otherPrice): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:131](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L131)

#### Parameters

##### otherPrice

[`IPrice`](../interfaces/IPrice.md)

#### Returns

`boolean`

#### See

IPrice.hasSameDenominations

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`hasSameDenominations`](../interfaces/IPrice.md#hassamedenominations)

***

### hasSameQuote()

```ts
hasSameQuote(otherPrice): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:113](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L113)

#### Parameters

##### otherPrice

[`IPrice`](../interfaces/IPrice.md)

#### Returns

`boolean`

#### See

IPrice.hasSameQuote

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`hasSameQuote`](../interfaces/IPrice.md#hassamequote)

***

### invert()

```ts
invert(): IPrice;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:210](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L210)

#### Returns

[`IPrice`](../interfaces/IPrice.md)

#### See

IPrice.invert

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`invert`](../interfaces/IPrice.md#invert)

***

### isEqual()

```ts
isEqual(otherPrice): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:252](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L252)

#### Parameters

##### otherPrice

[`IPrice`](../interfaces/IPrice.md)

#### Returns

`boolean`

#### See

IPrice.isEqual

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`isEqual`](../interfaces/IPrice.md#isequal)

***

### isGreaterThan()

```ts
isGreaterThan(otherPrice): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:233](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L233)

#### Parameters

##### otherPrice

[`IPrice`](../interfaces/IPrice.md)

#### Returns

`boolean`

#### See

IPrice.isGreaterThan

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`isGreaterThan`](../interfaces/IPrice.md#isgreaterthan)

***

### isGreaterThanOrEqual()

```ts
isGreaterThanOrEqual(otherPrice): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:240](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L240)

#### Parameters

##### otherPrice

[`IPrice`](../interfaces/IPrice.md)

#### Returns

`boolean`

#### See

IPrice.isGreaterThanOrEqual

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`isGreaterThanOrEqual`](../interfaces/IPrice.md#isgreaterthanorequal)

***

### isLessThan()

```ts
isLessThan(otherPrice): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:219](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L219)

#### Parameters

##### otherPrice

[`IPrice`](../interfaces/IPrice.md)

#### Returns

`boolean`

#### See

IPrice.isLessThan

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`isLessThan`](../interfaces/IPrice.md#islessthan)

***

### isLessThanOrEqual()

```ts
isLessThanOrEqual(otherPrice): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:226](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L226)

#### Parameters

##### otherPrice

[`IPrice`](../interfaces/IPrice.md)

#### Returns

`boolean`

#### See

IPrice.isLessThanOrEqual

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`isLessThanOrEqual`](../interfaces/IPrice.md#islessthanorequal)

***

### isZero()

```ts
isZero(): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:247](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L247)

#### Returns

`boolean`

#### See

IPrice.isZero

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`isZero`](../interfaces/IPrice.md#iszero)

***

### multiply()

```ts
multiply<InputParams, ReturnType>(multiplier): ReturnType;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:158](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L158)

#### Type Parameters

##### InputParams

`InputParams` *extends* [`PriceMulParamType`](../type-aliases/PriceMulParamType.md)

##### ReturnType

`ReturnType` = [`PriceMulReturnType`](../type-aliases/PriceMulReturnType.md)\<`InputParams`\>

#### Parameters

##### multiplier

`InputParams`

#### Returns

`ReturnType`

#### See

IPrice.multiply

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`multiply`](../interfaces/IPrice.md#multiply)

***

### subtract()

```ts
subtract(otherPrice): IPrice;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:147](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L147)

#### Parameters

##### otherPrice

[`IPrice`](../interfaces/IPrice.md)

#### Returns

[`IPrice`](../interfaces/IPrice.md)

#### See

IPrice.subtract

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`subtract`](../interfaces/IPrice.md#subtract)

***

### toBigNumber()

```ts
toBigNumber(): BigNumber;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:270](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L270)

#### Returns

`BigNumber`

#### See

IValueConverter.toBigNumber

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`toBigNumber`](../interfaces/IPrice.md#tobignumber)

***

### toSolidityValue()

```ts
toSolidityValue(params): bigint;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:264](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L264)

#### Parameters

##### params

###### decimals

`number`

#### Returns

`bigint`

#### See

IValueConverter.toSolidityValue

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`toSolidityValue`](../interfaces/IPrice.md#tosolidityvalue)

***

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:259](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L259)

#### Returns

`string`

#### See

IPrice.toString

#### Implementation of

[`IPrice`](../interfaces/IPrice.md).[`toString`](../interfaces/IPrice.md#tostring)

***

### createFrom()

```ts
static createFrom(params): IPrice;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:56](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L56)

FACTORY

#### Parameters

##### params

[`PriceParameters`](../type-aliases/PriceParameters.md)

#### Returns

[`IPrice`](../interfaces/IPrice.md)

***

### createFromAmountsRatio()

```ts
static createFromAmountsRatio(params): IPrice;
```

Defined in: [sdk/sdk-common/src/common/implementation/Price.ts:69](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Price.ts#L69)

Creates a price from the ratio of two token amounts

#### Parameters

##### params

###### denominator

[`ITokenAmount`](../interfaces/ITokenAmount.md)

###### numerator

[`ITokenAmount`](../interfaces/ITokenAmount.md)

#### Returns

[`IPrice`](../interfaces/IPrice.md)

the price calculated from the amounts ratio of numerator divided by denominator

#### Dev

The denominator becomes the base of the price and the numerator becomes the quote
