# Class: RefinanceParameters

Defined in: [sdk/sdk-common/src/orders/refinance/implementation/RefinanceParameters.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/refinance/implementation/RefinanceParameters.ts#L20)

## Name

RefinanceParameters

## See

IRefinanceParameters

## Implements

- [`IRefinanceParameters`](../interfaces/IRefinanceParameters.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/orders/refinance/implementation/RefinanceParameters.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/refinance/implementation/RefinanceParameters.ts#L22)

SIGNATURE

#### Implementation of

[`IRefinanceParameters`](../interfaces/IRefinanceParameters.md).[`[___signature__]`](../interfaces/IRefinanceParameters.md#___signature__)

***

### slippage

```ts
readonly slippage: IPercentage;
```

Defined in: [sdk/sdk-common/src/orders/refinance/implementation/RefinanceParameters.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/refinance/implementation/RefinanceParameters.ts#L27)

Maximum slippage allowed for the simulation

#### Implementation of

[`IRefinanceParameters`](../interfaces/IRefinanceParameters.md).[`slippage`](../interfaces/IRefinanceParameters.md#slippage)

***

### sourcePosition

```ts
readonly sourcePosition: ILendingPosition;
```

Defined in: [sdk/sdk-common/src/orders/refinance/implementation/RefinanceParameters.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/refinance/implementation/RefinanceParameters.ts#L25)

ATTRIBUTES

#### Implementation of

[`IRefinanceParameters`](../interfaces/IRefinanceParameters.md).[`sourcePosition`](../interfaces/IRefinanceParameters.md#sourceposition)

***

### targetPool

```ts
readonly targetPool: ILendingPool;
```

Defined in: [sdk/sdk-common/src/orders/refinance/implementation/RefinanceParameters.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/refinance/implementation/RefinanceParameters.ts#L26)

Target pool where the source position will be moved

#### Implementation of

[`IRefinanceParameters`](../interfaces/IRefinanceParameters.md).[`targetPool`](../interfaces/IRefinanceParameters.md#targetpool)

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/orders/refinance/implementation/RefinanceParameters.ts:44](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/refinance/implementation/RefinanceParameters.ts#L44)

#### Returns

`string`

#### See

IPrintable.toString

***

### createFrom()

```ts
static createFrom(params): RefinanceParameters;
```

Defined in: [sdk/sdk-common/src/orders/refinance/implementation/RefinanceParameters.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/refinance/implementation/RefinanceParameters.ts#L30)

FACTORY

#### Parameters

##### params

[`RefinanceParametersParameters`](../type-aliases/RefinanceParametersParameters.md)

#### Returns

`RefinanceParameters`
