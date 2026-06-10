# Interface: IRiskRatio

Defined in: [sdk/sdk-common/src/common/interfaces/IRiskRatio.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IRiskRatio.ts#L27)

## Name

IRiskRatio

## Description

Interface for the implementors of the risk ratio

## Extends

- [`IRiskRatioData`](../type-aliases/IRiskRatioData.md).[`IPrintable`](IPrintable.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IRiskRatio.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IRiskRatio.ts#L29)

Signature to differentiate from similar interfaces

***

### type

```ts
readonly type: RiskRatioType;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IRiskRatio.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IRiskRatio.ts#L31)

The type of the risk ratio

#### Overrides

```ts
IRiskRatioData.type
```

***

### value

```ts
readonly value: number | IPercentage;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IRiskRatio.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IRiskRatio.ts#L33)

The risk ratio value, a percentage for LTV and Collateralization Ratio, a number for Multiple

#### Overrides

```ts
IRiskRatioData.value
```

## Methods

### toCollateralizationRatio()

```ts
toCollateralizationRatio(): IPercentage;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IRiskRatio.ts:36](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IRiskRatio.ts#L36)

Gets the LTV value as a collateralization ratio

#### Returns

[`IPercentage`](IPercentage.md)

***

### toLTV()

```ts
toLTV(): IPercentage;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IRiskRatio.ts:42](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IRiskRatio.ts#L42)

Gets the LTV value

#### Returns

[`IPercentage`](IPercentage.md)

***

### toMultiple()

```ts
toMultiple(): number;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IRiskRatio.ts:39](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IRiskRatio.ts#L39)

Gets the LTV value as a multiply factor

#### Returns

`number`

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
