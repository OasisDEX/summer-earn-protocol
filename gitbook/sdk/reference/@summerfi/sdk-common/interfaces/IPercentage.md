# Interface: IPercentage

Defined in: [sdk/sdk-common/src/common/interfaces/IPercentage.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPercentage.ts#L14)

## Name

IPercentage

## Description

Percentage type that can be used for calculations with other types like TokenAmount or Price

## Extends

- [`IPercentageData`](../type-aliases/IPercentageData.md).`IValueConverter`.[`IPrintable`](IPrintable.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPercentage.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPercentage.ts#L16)

Signature to differentiate from similar interfaces

***

### value

```ts
readonly value: number;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPercentage.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPercentage.ts#L18)

The percentage in floating point format

#### Overrides

```ts
IPercentageData.value
```

## Methods

### add()

```ts
add(percentage): IPercentage;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPercentage.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPercentage.ts#L25)

#### Parameters

##### percentage

`IPercentage`

Percentage to add

#### Returns

`IPercentage`

the result of the addition

#### Name

add

***

### divide()

```ts
divide(divisor): IPercentage;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPercentage.ts:46](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPercentage.ts#L46)

#### Parameters

##### divisor

A percentage, string amount or number to divide

`string` | `number` | `IPercentage`

#### Returns

`IPercentage`

The resulting percentage

#### Name

divide

***

### multiply()

```ts
multiply(multiplier): IPercentage;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPercentage.ts:39](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPercentage.ts#L39)

#### Parameters

##### multiplier

A percentage, string amount or number to multiply

`string` | `number` | `IPercentage`

#### Returns

`IPercentage`

The resulting percentage

#### Name

multiply

***

### subtract()

```ts
subtract(percentage): IPercentage;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPercentage.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPercentage.ts#L32)

#### Parameters

##### percentage

[`IPercentageData`](../type-aliases/IPercentageData.md)

Percentage to subtract

#### Returns

`IPercentage`

the result of the subtraction

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

### toComplement()

```ts
toComplement(): IPercentage;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPercentage.ts:62](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPercentage.ts#L62)

#### Returns

`IPercentage`

The complement of the percentage

The complement is the difference between 100% and the percentage

#### Name

toComplement

***

### toProportion()

```ts
toProportion(): number;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPercentage.ts:54](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPercentage.ts#L54)

#### Returns

`number`

Returns the equivalent proportion of the percentage

The proportion is the percentage divided by 100, this is, a floating value between 0 and 1

#### Name

toProportion

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
