# Class: TokenAmount

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L28)

TokenAmount

## See

ITokenAmount

## Implements

- [`ITokenAmount`](../interfaces/ITokenAmount.md)

## Properties

### \_baseUnitFactor

```ts
protected readonly _baseUnitFactor: BigNumber;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:38](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L38)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L30)

SIGNATURE

#### Implementation of

[`ITokenAmount`](../interfaces/ITokenAmount.md).[`[___signature__]`](../interfaces/ITokenAmount.md#___signature__)

***

### amount

```ts
readonly amount: string;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:34](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L34)

Amount in floating point format without taking into account the token decimals

#### Implementation of

[`ITokenAmount`](../interfaces/ITokenAmount.md).[`amount`](../interfaces/ITokenAmount.md#amount)

***

### token

```ts
readonly token: ITokenStanalone;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L33)

ATTRIBUTES

#### Implementation of

[`ITokenAmount`](../interfaces/ITokenAmount.md).[`token`](../interfaces/ITokenAmount.md#token)

## Methods

### add()

```ts
add(tokenToAdd): ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:74](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L74)

#### Parameters

##### tokenToAdd

[`ITokenAmount`](../interfaces/ITokenAmount.md)

#### Returns

[`ITokenAmount`](../interfaces/ITokenAmount.md)

#### See

ITokenAmount.add

#### Implementation of

[`ITokenAmount`](../interfaces/ITokenAmount.md).[`add`](../interfaces/ITokenAmount.md#add)

***

### divide()

```ts
divide<InputParams, ReturnType>(divisor): ReturnType;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:122](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L122)

#### Type Parameters

##### InputParams

`InputParams` *extends* [`TokenAmountMulDivParamType`](../type-aliases/TokenAmountMulDivParamType.md)

##### ReturnType

`ReturnType` = [`TokenAmountMulDivReturnType`](../type-aliases/TokenAmountMulDivReturnType.md)\<`InputParams`\>

#### Parameters

##### divisor

`InputParams`

#### Returns

`ReturnType`

#### See

ITokenAmount.divide

#### Implementation of

[`ITokenAmount`](../interfaces/ITokenAmount.md).[`divide`](../interfaces/ITokenAmount.md#divide)

***

### isEqualTo()

```ts
isEqualTo(tokenAmount): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:167](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L167)

#### Parameters

##### tokenAmount

[`ITokenAmount`](../interfaces/ITokenAmount.md)

#### Returns

`boolean`

#### See

ITokenAmount.isEqualTo

#### Implementation of

[`ITokenAmount`](../interfaces/ITokenAmount.md).[`isEqualTo`](../interfaces/ITokenAmount.md#isequalto)

***

### isGreaterOrEqualThan()

```ts
isGreaterOrEqualThan(tokenAmount): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:157](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L157)

#### Parameters

##### tokenAmount

[`ITokenAmount`](../interfaces/ITokenAmount.md)

#### Returns

`boolean`

#### See

ITokenAmount.isGreaterOrEqualThan

#### Implementation of

[`ITokenAmount`](../interfaces/ITokenAmount.md).[`isGreaterOrEqualThan`](../interfaces/ITokenAmount.md#isgreaterorequalthan)

***

### isGreaterThan()

```ts
isGreaterThan(tokenAmount): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:143](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L143)

#### Parameters

##### tokenAmount

[`ITokenAmount`](../interfaces/ITokenAmount.md)

#### Returns

`boolean`

#### See

ITokenAmount.isGreaterThan

#### Implementation of

[`ITokenAmount`](../interfaces/ITokenAmount.md).[`isGreaterThan`](../interfaces/ITokenAmount.md#isgreaterthan)

***

### isLessOrEqualThan()

```ts
isLessOrEqualThan(tokenAmount): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:162](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L162)

#### Parameters

##### tokenAmount

[`ITokenAmount`](../interfaces/ITokenAmount.md)

#### Returns

`boolean`

#### See

ITokenAmount.isLessOrEqualThan

#### Implementation of

[`ITokenAmount`](../interfaces/ITokenAmount.md).[`isLessOrEqualThan`](../interfaces/ITokenAmount.md#islessorequalthan)

***

### isLessThan()

```ts
isLessThan(tokenAmount): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:150](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L150)

#### Parameters

##### tokenAmount

[`ITokenAmount`](../interfaces/ITokenAmount.md)

#### Returns

`boolean`

#### See

ITokenAmount.isLessThan

#### Implementation of

[`ITokenAmount`](../interfaces/ITokenAmount.md).[`isLessThan`](../interfaces/ITokenAmount.md#islessthan)

***

### isZero()

```ts
isZero(): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:138](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L138)

#### Returns

`boolean`

#### See

ITokenAmount.isZero

#### Implementation of

[`ITokenAmount`](../interfaces/ITokenAmount.md).[`isZero`](../interfaces/ITokenAmount.md#iszero)

***

### multiply()

```ts
multiply<InputParams, ReturnType>(multiplier): ReturnType;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:103](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L103)

#### Type Parameters

##### InputParams

`InputParams` *extends* [`TokenAmountMulDivParamType`](../type-aliases/TokenAmountMulDivParamType.md)

##### ReturnType

`ReturnType` = [`TokenAmountMulDivReturnType`](../type-aliases/TokenAmountMulDivReturnType.md)\<`InputParams`\>

#### Parameters

##### multiplier

`InputParams`

#### Returns

`ReturnType`

#### See

ITokenAmount.multiply

#### Implementation of

[`ITokenAmount`](../interfaces/ITokenAmount.md).[`multiply`](../interfaces/ITokenAmount.md#multiply)

***

### subtract()

```ts
subtract(tokenToSubstract): ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:84](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L84)

#### Parameters

##### tokenToSubstract

[`ITokenAmount`](../interfaces/ITokenAmount.md)

#### Returns

[`ITokenAmount`](../interfaces/ITokenAmount.md)

#### See

ITokenAmount.subtract

#### Implementation of

[`ITokenAmount`](../interfaces/ITokenAmount.md).[`subtract`](../interfaces/ITokenAmount.md#subtract)

***

### toBigNumber()

```ts
toBigNumber(): BigNumber;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:184](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L184)

#### Returns

`BigNumber`

#### See

IValueConverter.toBigNumber

#### Implementation of

[`ITokenAmount`](../interfaces/ITokenAmount.md).[`toBigNumber`](../interfaces/ITokenAmount.md#tobignumber)

***

### toSolidityValue()

```ts
toSolidityValue(params): bigint;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:177](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L177)

#### Parameters

##### params

###### decimals

`number`

#### Returns

`bigint`

#### See

IValueConverter.toSolidityValue

#### Implementation of

[`ITokenAmount`](../interfaces/ITokenAmount.md).[`toSolidityValue`](../interfaces/ITokenAmount.md#tosolidityvalue)

***

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:172](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L172)

#### Returns

`string`

#### See

IPrintable.toString

#### Implementation of

[`ITokenAmount`](../interfaces/ITokenAmount.md).[`toString`](../interfaces/ITokenAmount.md#tostring)

***

### createFrom()

```ts
static createFrom(params): ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:42](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L42)

FACTORY

#### Parameters

##### params

[`TokenAmountParameters`](../type-aliases/TokenAmountParameters.md)

#### Returns

[`ITokenAmount`](../interfaces/ITokenAmount.md)

***

### createFromBaseUnit()

```ts
static createFromBaseUnit(params): ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/TokenAmount.ts:55](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/TokenAmount.ts#L55)

#### Parameters

##### params

[`TokenAmountParameters`](../type-aliases/TokenAmountParameters.md)

Token amount data to create the instance

#### Returns

[`ITokenAmount`](../interfaces/ITokenAmount.md)

The resulting TokenAmount

`amount` is the integer amount including all the decimals of the token

i.e.: amount in base unit (1eth = 1000000000000000000, 1btc = 100000000, etc...)

#### Name

createFromBaseUnit
