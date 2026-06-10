# Class: FiatCurrencyAmount

Defined in: [sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts#L27)

FiatCurrencyAmount

## See

IFiatCurrencyAmount

## Implements

- [`IFiatCurrencyAmount`](../interfaces/IFiatCurrencyAmount.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts#L29)

SIGNATURE

#### Implementation of

[`IFiatCurrencyAmount`](../interfaces/IFiatCurrencyAmount.md).[`[___signature__]`](../interfaces/IFiatCurrencyAmount.md#___signature__)

***

### amount

```ts
readonly amount: string;
```

Defined in: [sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts#L32)

The amount in floating point format

#### Implementation of

[`IFiatCurrencyAmount`](../interfaces/IFiatCurrencyAmount.md).[`amount`](../interfaces/IFiatCurrencyAmount.md#amount)

***

### fiat

```ts
readonly fiat: FiatCurrency;
```

Defined in: [sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts#L31)

Fiat currency for the amount

#### Implementation of

[`IFiatCurrencyAmount`](../interfaces/IFiatCurrencyAmount.md).[`fiat`](../interfaces/IFiatCurrencyAmount.md#fiat)

## Methods

### add()

```ts
add(fiatToAdd): IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts:48](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts#L48)

#### Parameters

##### fiatToAdd

`FiatCurrencyAmount`

#### Returns

[`IFiatCurrencyAmount`](../interfaces/IFiatCurrencyAmount.md)

#### See

IFiatCurrencyAmount.add

#### Implementation of

[`IFiatCurrencyAmount`](../interfaces/IFiatCurrencyAmount.md).[`add`](../interfaces/IFiatCurrencyAmount.md#add)

***

### divide()

```ts
divide<InputParams, ReturnType>(divisor): ReturnType;
```

Defined in: [sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts:87](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts#L87)

#### Type Parameters

##### InputParams

`InputParams` *extends* [`FiatCurrencyAmountMulDivParamType`](../type-aliases/FiatCurrencyAmountMulDivParamType.md)

##### ReturnType

`ReturnType` = [`FiatCurrencyAmountMulDivReturnType`](../type-aliases/FiatCurrencyAmountMulDivReturnType.md)\<`InputParams`\>

#### Parameters

##### divisor

`InputParams`

#### Returns

`ReturnType`

#### See

IFiatCurrencyAmount.divide

#### Implementation of

[`IFiatCurrencyAmount`](../interfaces/IFiatCurrencyAmount.md).[`divide`](../interfaces/IFiatCurrencyAmount.md#divide)

***

### multiply()

```ts
multiply<InputParams, ReturnType>(multiplier): ReturnType;
```

Defined in: [sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts:68](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts#L68)

#### Type Parameters

##### InputParams

`InputParams` *extends* [`FiatCurrencyAmountMulDivParamType`](../type-aliases/FiatCurrencyAmountMulDivParamType.md)

##### ReturnType

`ReturnType` = [`FiatCurrencyAmountMulDivReturnType`](../type-aliases/FiatCurrencyAmountMulDivReturnType.md)\<`InputParams`\>

#### Parameters

##### multiplier

`InputParams`

#### Returns

`ReturnType`

#### See

IFiatCurrencyAmount.multiply

#### Implementation of

[`IFiatCurrencyAmount`](../interfaces/IFiatCurrencyAmount.md).[`multiply`](../interfaces/IFiatCurrencyAmount.md#multiply)

***

### subtract()

```ts
subtract(fiatToSubstract): IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts:58](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts#L58)

#### Parameters

##### fiatToSubstract

`FiatCurrencyAmount`

#### Returns

[`IFiatCurrencyAmount`](../interfaces/IFiatCurrencyAmount.md)

#### See

IFiatCurrencyAmount.subtract

#### Implementation of

[`IFiatCurrencyAmount`](../interfaces/IFiatCurrencyAmount.md).[`subtract`](../interfaces/IFiatCurrencyAmount.md#subtract)

***

### toBigNumber()

```ts
toBigNumber(): BigNumber;
```

Defined in: [sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts:112](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts#L112)

#### Returns

`BigNumber`

#### See

IValueConverter.toBigNumber

#### Implementation of

[`IFiatCurrencyAmount`](../interfaces/IFiatCurrencyAmount.md).[`toBigNumber`](../interfaces/IFiatCurrencyAmount.md#tobignumber)

***

### toSolidityValue()

```ts
toSolidityValue(params?): bigint;
```

Defined in: [sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts:106](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts#L106)

#### Parameters

##### params?

###### decimals

`number`

#### Returns

`bigint`

#### See

IValueConverter.toBigNumber

#### Implementation of

[`IFiatCurrencyAmount`](../interfaces/IFiatCurrencyAmount.md).[`toSolidityValue`](../interfaces/IFiatCurrencyAmount.md#tosolidityvalue)

***

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts:117](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts#L117)

#### Returns

`string`

#### See

IPrintable.toString

#### Implementation of

[`IFiatCurrencyAmount`](../interfaces/IFiatCurrencyAmount.md).[`toString`](../interfaces/IFiatCurrencyAmount.md#tostring)

***

### createFrom()

```ts
static createFrom(params): IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts:35](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/FiatCurrencyAmount.ts#L35)

FACTORY

#### Parameters

##### params

[`FiatCurrencyAmountParameters`](../type-aliases/FiatCurrencyAmountParameters.md)

#### Returns

[`IFiatCurrencyAmount`](../interfaces/IFiatCurrencyAmount.md)
