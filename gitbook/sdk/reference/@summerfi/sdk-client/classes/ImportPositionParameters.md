# Class: ImportPositionParameters

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ImportPositionParameters.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ImportPositionParameters.ts#L19)

## Name

ImportPositionParameters

## See

IImportPositionParameters

## Implements

- [`IImportPositionParameters`](../interfaces/IImportPositionParameters.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ImportPositionParameters.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ImportPositionParameters.ts#L21)

SIGNATURE

#### Implementation of

[`IImportPositionParameters`](../interfaces/IImportPositionParameters.md).[`[___signature__]`](../interfaces/IImportPositionParameters.md#___signature__)

***

### externalPosition

```ts
readonly externalPosition: IExternalLendingPosition;
```

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ImportPositionParameters.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ImportPositionParameters.ts#L24)

ATTRIBUTES

#### Implementation of

[`IImportPositionParameters`](../interfaces/IImportPositionParameters.md).[`externalPosition`](../interfaces/IImportPositionParameters.md#externalposition)

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ImportPositionParameters.ts:39](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ImportPositionParameters.ts#L39)

#### Returns

`string`

#### See

IPrintable.toString

***

### createFrom()

```ts
static createFrom(params): ImportPositionParameters;
```

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ImportPositionParameters.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ImportPositionParameters.ts#L27)

FACTORY

#### Parameters

##### params

[`ImportPositionParametersParameters`](../type-aliases/ImportPositionParametersParameters.md)

#### Returns

`ImportPositionParameters`
