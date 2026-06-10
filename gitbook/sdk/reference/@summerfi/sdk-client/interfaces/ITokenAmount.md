# Interface: ITokenAmount

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L32)

## Name

ITokenAmount

## Description

Interface for the implementors of the token amount

This interface is used to add all the methods that the interface supports

## Extends

- [`ITokenAmountData`](../type-aliases/ITokenAmountData.md).`IValueConverter`.[`IPrintable`](IPrintable.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:34](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L34)

Signature to differentiate from similar interfaces

***

### amount

```ts
readonly amount: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:38](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L38)

Amount in floating point format without taking into account the token decimals

#### Overrides

```ts
ITokenAmountData.amount
```

***

### token

```ts
readonly token: ITokenStanalone;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:36](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L36)

Token this amount refers to

#### Overrides

```ts
ITokenAmountData.token
```

## Methods

### add()

```ts
add(tokenToAdd): ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:45](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L45)

#### Parameters

##### tokenToAdd

`ITokenAmount`

TokenAmount to add

#### Returns

`ITokenAmount`

The resulting TokenAmount

#### Name

add

***

### divide()

```ts
divide<InputParams, ReturnType>(divisor): ReturnType;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:71](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L71)

#### Type Parameters

##### InputParams

`InputParams` *extends* [`TokenAmountMulDivParamType`](../type-aliases/TokenAmountMulDivParamType.md)

##### ReturnType

`ReturnType` = [`TokenAmountMulDivReturnType`](../type-aliases/TokenAmountMulDivReturnType.md)\<`InputParams`\>

#### Parameters

##### divisor

`InputParams`

A percentage, price, string amount or number to divide

#### Returns

`ReturnType`

The resulting TokenAmount

#### Name

divide

***

### isEqualTo()

```ts
isEqualTo(tokenAmount): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:123](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L123)

#### Parameters

##### tokenAmount

`ITokenAmount`

TokenAmount to compare

#### Returns

`boolean`

true if the amount is equal to the provided TokenAmount

#### Name

isEqualTo

#### Description

Checks if the amount is equal to the provided TokenAmount

***

### isGreaterOrEqualThan()

```ts
isGreaterOrEqualThan(tokenAmount): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:107](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L107)

#### Parameters

##### tokenAmount

`ITokenAmount`

TokenAmount to compare

#### Returns

`boolean`

true if the amount is greater or equal than the provided TokenAmount

#### Name

isGreaterOrEqualThan

#### Description

Checks if the amount is greater or equal than the provided TokenAmount

***

### isGreaterThan()

```ts
isGreaterThan(tokenAmount): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:91](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L91)

#### Parameters

##### tokenAmount

`ITokenAmount`

TokenAmount to compare

#### Returns

`boolean`

true if the amount is greater than the provided TokenAmount

#### Name

isGreaterThan

#### Description

Checks if the amount is greater than the provided TokenAmount

***

### isLessOrEqualThan()

```ts
isLessOrEqualThan(tokenAmount): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:115](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L115)

#### Parameters

##### tokenAmount

`ITokenAmount`

TokenAmount to compare

#### Returns

`boolean`

true if the amount is less or equal than the provided TokenAmount

#### Name

isLessOrEqualThan

#### Description

Checks if the amount is less or equal than the provided TokenAmount

***

### isLessThan()

```ts
isLessThan(tokenAmount): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:99](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L99)

#### Parameters

##### tokenAmount

`ITokenAmount`

TokenAmount to compare

#### Returns

`boolean`

true if the amount is less than the provided TokenAmount

#### Name

isLessThan

#### Description

Checks if the amount is less than the provided TokenAmount

***

### isZero()

```ts
isZero(): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:83](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L83)

#### Returns

`boolean`

true if the amount is zero or false otherwise

#### Name

isZero

#### Description

Checks if the amount is zero

***

### multiply()

```ts
multiply<InputParams, ReturnType>(multiplier): ReturnType;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:59](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L59)

#### Type Parameters

##### InputParams

`InputParams` *extends* [`TokenAmountMulDivParamType`](../type-aliases/TokenAmountMulDivParamType.md)

##### ReturnType

`ReturnType` = [`TokenAmountMulDivReturnType`](../type-aliases/TokenAmountMulDivReturnType.md)\<`InputParams`\>

#### Parameters

##### multiplier

`InputParams`

A percentage, price, string amount or number to multiply

#### Returns

`ReturnType`

The resulting TokenAmount

#### Name

multiply

***

### subtract()

```ts
subtract(tokenToSubstract): ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:52](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L52)

#### Parameters

##### tokenToSubstract

`ITokenAmount`

TokenAmount to subtract

#### Returns

`ITokenAmount`

The resulting TokenAmount

#### Name

subtract

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

Defined in: [sdk/sdk-common/src/common/interfaces/IPrintable.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrintable.ts#L15)

#### Returns

`string`

string

The string representation should have enough info to debug the object

#### Name

toString

#### Description

Returns a string representation of the object

#### Inherited from

[`IPrintable`](IPrintable.md).[`toString`](IPrintable.md#tostring)
