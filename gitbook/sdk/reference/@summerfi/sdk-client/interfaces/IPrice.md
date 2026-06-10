# Interface: IPrice

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:54](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L54)

## Name

IPrice

## Description

Represents a price for a token with certain denomation. The denomination can be a fiat currency
             or another token

The price is represented as a string in floating point format without taking into consideration
the number of decimals of the tokens. This data type can be used for calculations with other types
like TokenAmount or Percentage

Typically in exchanges the price is represented in the following format:

BASE/QUOTE

Base is the token that is being traded, and quote is the token that is received as part of the trade

In that format the slash in between the base and the quote is not a quotient or fraction,
and it is just used to separate the two tokens.

The mathematical representation of the price units is instead:

QUOTE/BASE

## Extends

- [`IPriceData`](../type-aliases/IPriceData.md).`IValueConverter`.[`IPrintable`](IPrintable.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:56](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L56)

Signature to differentiate from similar interfaces

***

### base

```ts
readonly base: Denomination;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:60](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L60)

The token for the base of the price

#### Overrides

```ts
IPriceData.base
```

***

### quote

```ts
readonly quote: Denomination;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:62](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L62)

The token for the quote of the price

#### Overrides

```ts
IPriceData.quote
```

***

### value

```ts
readonly value: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:58](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L58)

The price value in floating point format without taking into account decimals

#### Overrides

```ts
IPriceData.value
```

## Methods

### add()

```ts
add(otherPrice): IPrice;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:96](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L96)

#### Parameters

##### otherPrice

`IPrice`

The price to add

#### Returns

`IPrice`

The resulting price

#### Name

add

#### Description

Adds the price to another price

#### Throws

If the prices have different base tokens or quote tokens

***

### divide()

```ts
divide(divider): IPrice;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:130](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L130)

#### Parameters

##### divider

The numeric string, number or price to divide by

`string` | `number` | `IPrice`

#### Returns

`IPrice`

The resulting price

#### Name

divide

#### Description

Divides the price by another price or a constant

#### Throws

If the second price base is not the same as this price base
        or if the second price quote is not the same as this price quote

***

### hasSameBase()

```ts
hasSameBase(otherPrice): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:78](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L78)

#### Parameters

##### otherPrice

`IPrice`

The price to compare against

#### Returns

`boolean`

true if the prices have the same base token

#### Name

hasSameBase

#### Description

Checks if the price has the same base as another price

***

### hasSameDenominations()

```ts
hasSameDenominations(otherPrice): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:86](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L86)

#### Parameters

##### otherPrice

`IPrice`

The price to compare against

#### Returns

`boolean`

true if the prices have the same base and quote

#### Name

hasSameDenominations

#### Description

Checks if the price has the same base and quote as another price

***

### hasSameQuote()

```ts
hasSameQuote(otherPrice): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:70](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L70)

#### Parameters

##### otherPrice

`IPrice`

The price to compare against

#### Returns

`boolean`

true if the prices have the same quote

#### Name

hasSameQuote

#### Description

Checks if the price has the same quote as another price

***

### invert()

```ts
invert(): IPrice;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:137](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L137)

#### Returns

`IPrice`

The inverted price

#### Name

invert

#### Description

Inverts the price

***

### isEqual()

```ts
isEqual(otherPrice): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:179](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L179)

#### Parameters

##### otherPrice

`IPrice`

#### Returns

`boolean`

#### Name

isEqual

#### Description

Checks if the price is equal to another price

***

### isGreaterThan()

```ts
isGreaterThan(otherPrice): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:161](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L161)

#### Parameters

##### otherPrice

`IPrice`

#### Returns

`boolean`

#### Name

isGreaterThan

#### Description

Checks if the price is greater than another price

***

### isGreaterThanOrEqual()

```ts
isGreaterThanOrEqual(otherPrice): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:167](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L167)

#### Parameters

##### otherPrice

`IPrice`

#### Returns

`boolean`

#### Name

isGreaterThanOrEqual

#### Description

Checks if the price is greater than or equal to another price

***

### isLessThan()

```ts
isLessThan(otherPrice): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:149](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L149)

#### Parameters

##### otherPrice

`IPrice`

#### Returns

`boolean`

#### Name

isLessThan

#### Description

Checks if the price is less than another price

***

### isLessThanOrEqual()

```ts
isLessThanOrEqual(otherPrice): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:155](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L155)

#### Parameters

##### otherPrice

`IPrice`

#### Returns

`boolean`

#### Name

isLessThanOrEqual

#### Description

Checks if the price is less than or equal to another price

***

### isZero()

```ts
isZero(): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:173](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L173)

#### Returns

`boolean`

#### Name

isZero

#### Description

Checks if the price is zero

***

### multiply()

```ts
multiply<InputParams, ReturnType>(multiplier): ReturnType;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:117](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L117)

#### Type Parameters

##### InputParams

`InputParams` *extends* [`PriceMulParamType`](../type-aliases/PriceMulParamType.md)

##### ReturnType

`ReturnType` = [`PriceMulReturnType`](../type-aliases/PriceMulReturnType.md)\<`InputParams`\>

#### Parameters

##### multiplier

`InputParams`

The numeric string, number, price, token amount or fiat currency amount to multiply by

#### Returns

`ReturnType`

The resulting price, token amount or fiat currency amount

#### Name

multiply

#### Description

Multiplies the price by another price or a constant

#### Throws

When it is a price, if the second price quote is not the same as this price base or
        if the second price base is not the same as this price quote it will throw an error

***

### subtract()

```ts
subtract(otherPrice): IPrice;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:106](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L106)

#### Parameters

##### otherPrice

`IPrice`

The price to subtract

#### Returns

`IPrice`

The resulting price

#### Name

subtract

#### Description

Subtracts the price from another price

#### Throws

If the prices have different base tokens or quote tokens

***

### toBigNumber()

```ts
toBigNumber(): BigNumber;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IValueConverter.ts:37](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IValueConverter.ts#L37)

Converts the instance into a BigNumber

#### Returns

`BigNumber`

The value as a BigNumber

#### Remarks

It returns a BigNumber without explicit decimals. This function is intended for low
         level operations not accounted for in the specific data type. The BigNumber does NOT
         carry any information on how many decimals the value has, meaning that the conversion
         of BigNumber to a Solidity value must be done manually

#### Inherited from

```ts
IValueConverter.toBigNumber
```

***

### toSolidityValue()

```ts
toSolidityValue(params?): bigint;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IValueConverter.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IValueConverter.ts#L23)

Converts the instance into a Solidity value

#### Parameters

##### params?

###### decimals

`number`

#### Returns

`bigint`

The value as a TypeScript bigint that can be passed to a Solidity contract

#### Remarks

The value is expected to be scaled by 10^decimals, thus yielding a Solidity uint256
         value with the correct fixed point decimals

#### Inherited from

```ts
IValueConverter.toSolidityValue
```

***

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:143](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L143)

#### Returns

`string`

#### Name

toString

#### Description

Converts the price to a string

#### Overrides

[`IPrintable`](IPrintable.md).[`toString`](IPrintable.md#tostring)
