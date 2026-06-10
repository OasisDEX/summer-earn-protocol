# Class: Percentage

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L19)

Percentage

## See

IPercentage

## Implements

- [`IPercentage`](../interfaces/IPercentage.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L21)

SIGNATURE

#### Implementation of

[`IPercentage`](../interfaces/IPercentage.md).[`[___signature__]`](../interfaces/IPercentage.md#___signature__)

***

### value

```ts
readonly value: number;
```

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:37](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L37)

ATTRIBUTES

#### Implementation of

[`IPercentage`](../interfaces/IPercentage.md).[`value`](../interfaces/IPercentage.md#value)

***

### Percent100

```ts
static Percent100: Percentage;
```

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L32)

The percentage of 100% with the given `PERCENTAGE_DECIMALS`

***

### PERCENTAGE\_DECIMALS

```ts
static PERCENTAGE_DECIMALS: number = 6;
```

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L26)

The number of decimals used to represent the percentage in Solidity

***

### PERCENTAGE\_FACTOR

```ts
static PERCENTAGE_FACTOR: number;
```

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L29)

The factor used to scale the percentage

## Methods

### add()

```ts
add(percentage): IPercentage;
```

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:67](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L67)

#### Parameters

##### percentage

[`IPercentage`](../interfaces/IPercentage.md)

#### Returns

[`IPercentage`](../interfaces/IPercentage.md)

#### See

IPercentage.add

#### Implementation of

[`IPercentage`](../interfaces/IPercentage.md).[`add`](../interfaces/IPercentage.md#add)

***

### divide()

```ts
divide(divisor): IPercentage;
```

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:86](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L86)

#### Parameters

##### divisor

`string` | `number` | [`IPercentage`](../interfaces/IPercentage.md)

#### Returns

[`IPercentage`](../interfaces/IPercentage.md)

#### See

IPercentage.divide

#### Implementation of

[`IPercentage`](../interfaces/IPercentage.md).[`divide`](../interfaces/IPercentage.md#divide)

***

### multiply()

```ts
multiply(multiplier): IPercentage;
```

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:77](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L77)

#### Parameters

##### multiplier

`string` | `number` | [`IPercentage`](../interfaces/IPercentage.md)

#### Returns

[`IPercentage`](../interfaces/IPercentage.md)

#### See

IPercentage.multiply

#### Implementation of

[`IPercentage`](../interfaces/IPercentage.md).[`multiply`](../interfaces/IPercentage.md#multiply)

***

### subtract()

```ts
subtract(percentage): IPercentage;
```

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:72](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L72)

#### Parameters

##### percentage

[`IPercentage`](../interfaces/IPercentage.md)

#### Returns

[`IPercentage`](../interfaces/IPercentage.md)

#### See

IPercentage.subtract

#### Implementation of

[`IPercentage`](../interfaces/IPercentage.md).[`subtract`](../interfaces/IPercentage.md#subtract)

***

### toBigNumber()

```ts
toBigNumber(): BigNumber;
```

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:113](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L113)

#### Returns

`BigNumber`

#### See

IValueConverter.toBigNumber

#### Implementation of

[`IPercentage`](../interfaces/IPercentage.md).[`toBigNumber`](../interfaces/IPercentage.md#tobignumber)

***

### toComplement()

```ts
toComplement(): IPercentage;
```

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:100](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L100)

#### Returns

[`IPercentage`](../interfaces/IPercentage.md)

#### See

IPercentage.toComplement

#### Implementation of

[`IPercentage`](../interfaces/IPercentage.md).[`toComplement`](../interfaces/IPercentage.md#tocomplement)

***

### toProportion()

```ts
toProportion(): number;
```

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:95](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L95)

#### Returns

`number`

#### See

IPercentage.toProportion

#### Implementation of

[`IPercentage`](../interfaces/IPercentage.md).[`toProportion`](../interfaces/IPercentage.md#toproportion)

***

### toSolidityValue()

```ts
toSolidityValue(params): bigint;
```

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:105](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L105)

#### Parameters

##### params

###### decimals

`number`

#### Returns

`bigint`

#### See

IValueConverter.toSolidityValue

#### Implementation of

[`IPercentage`](../interfaces/IPercentage.md).[`toSolidityValue`](../interfaces/IPercentage.md#tosolidityvalue)

***

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:118](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L118)

#### Returns

`string`

#### See

IPrintable.toString

#### Implementation of

[`IPercentage`](../interfaces/IPercentage.md).[`toString`](../interfaces/IPercentage.md#tostring)

***

### createFrom()

```ts
static createFrom(params): Percentage;
```

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:40](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L40)

FACTORY

#### Parameters

##### params

[`PercentageParameters`](../type-aliases/PercentageParameters.md)

#### Returns

`Percentage`

***

### createFromSolidityValue()

```ts
static createFromSolidityValue(params): Percentage;
```

Defined in: [sdk/sdk-common/src/common/implementation/Percentage.ts:49](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Percentage.ts#L49)

Creates a Percentage instance from a Solidity value with PERCENTAGE_DECIMALS decimals

#### Parameters

##### params

###### value

`bigint`

#### Returns

`Percentage`

The Percentage instance
