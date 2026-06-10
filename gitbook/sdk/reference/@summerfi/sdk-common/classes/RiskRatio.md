# Class: RiskRatio

Defined in: [sdk/sdk-common/src/common/implementation/RiskRatio.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/RiskRatio.ts#L15)

RiskRatio

## See

IRiskRatio

## Implements

- [`IRiskRatio`](../interfaces/IRiskRatio.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/RiskRatio.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/RiskRatio.ts#L17)

SIGNATURE

#### Implementation of

[`IRiskRatio`](../interfaces/IRiskRatio.md).[`[___signature__]`](../interfaces/IRiskRatio.md#___signature__)

***

### type

```ts
readonly type: RiskRatioType;
```

Defined in: [sdk/sdk-common/src/common/implementation/RiskRatio.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/RiskRatio.ts#L20)

ATTRIBUTES

#### Implementation of

[`IRiskRatio`](../interfaces/IRiskRatio.md).[`type`](../interfaces/IRiskRatio.md#type)

***

### value

```ts
readonly value: number | IPercentage;
```

Defined in: [sdk/sdk-common/src/common/implementation/RiskRatio.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/RiskRatio.ts#L21)

The risk ratio value, a percentage for LTV and Collateralization Ratio, a number for Multiple

#### Implementation of

[`IRiskRatio`](../interfaces/IRiskRatio.md).[`value`](../interfaces/IRiskRatio.md#value)

## Methods

### toCollateralizationRatio()

```ts
toCollateralizationRatio(): IPercentage;
```

Defined in: [sdk/sdk-common/src/common/implementation/RiskRatio.ts:67](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/RiskRatio.ts#L67)

#### Returns

[`IPercentage`](../interfaces/IPercentage.md)

#### See

IRiskRatio.toCollateralizationRatio

#### Implementation of

[`IRiskRatio`](../interfaces/IRiskRatio.md).[`toCollateralizationRatio`](../interfaces/IRiskRatio.md#tocollateralizationratio)

***

### toLTV()

```ts
toLTV(): IPercentage;
```

Defined in: [sdk/sdk-common/src/common/implementation/RiskRatio.ts:81](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/RiskRatio.ts#L81)

#### Returns

[`IPercentage`](../interfaces/IPercentage.md)

#### See

IRiskRatio.toLTV

#### Implementation of

[`IRiskRatio`](../interfaces/IRiskRatio.md).[`toLTV`](../interfaces/IRiskRatio.md#toltv)

***

### toMultiple()

```ts
toMultiple(): number;
```

Defined in: [sdk/sdk-common/src/common/implementation/RiskRatio.ts:74](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/RiskRatio.ts#L74)

#### Returns

`number`

#### See

IRiskRatio.toMultiple

#### Implementation of

[`IRiskRatio`](../interfaces/IRiskRatio.md).[`toMultiple`](../interfaces/IRiskRatio.md#tomultiple)

***

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/implementation/RiskRatio.ts:86](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/RiskRatio.ts#L86)

#### Returns

`string`

#### See

IPrintable.toString

#### Implementation of

[`IRiskRatio`](../interfaces/IRiskRatio.md).[`toString`](../interfaces/IRiskRatio.md#tostring)

***

### createFrom()

```ts
static createFrom(params): RiskRatio;
```

Defined in: [sdk/sdk-common/src/common/implementation/RiskRatio.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/RiskRatio.ts#L26)

FACTORY

#### Parameters

##### params

[`RiskRatioParameters`](../type-aliases/RiskRatioParameters.md)

#### Returns

`RiskRatio`
