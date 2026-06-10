# Class: ImportSimulation

Defined in: [sdk/sdk-common/src/simulation/implementation/ImportSimulation.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/ImportSimulation.ts#L22)

## Name

ImportSimulation

## See

IImportSimulation

## Extends

- [`Simulation`](Simulation.md)

## Implements

- [`IImportSimulation`](../interfaces/IImportSimulation.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/simulation/implementation/ImportSimulation.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/ImportSimulation.ts#L24)

SIGNATURE

#### Implementation of

[`IImportSimulation`](../interfaces/IImportSimulation.md).[`[___signature__]`](../interfaces/IImportSimulation.md#___signature__-1)

#### Inherited from

[`Simulation`](Simulation.md).[`[___signature__]`](Simulation.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/simulation/implementation/Simulation.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/Simulation.ts#L16)

SIGNATURE

#### Implementation of

```ts
IImportSimulation.[___signature__]
```

#### Inherited from

[`RefinanceSimulation`](RefinanceSimulation.md).[`[___signature__]`](RefinanceSimulation.md#___signature__-1)

***

### sourcePosition

```ts
readonly sourcePosition: IExternalLendingPosition;
```

Defined in: [sdk/sdk-common/src/simulation/implementation/ImportSimulation.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/ImportSimulation.ts#L27)

ATTRIBUTES

#### Implementation of

[`IImportSimulation`](../interfaces/IImportSimulation.md).[`sourcePosition`](../interfaces/IImportSimulation.md#sourceposition)

***

### steps

```ts
readonly steps: Steps[];
```

Defined in: [sdk/sdk-common/src/simulation/implementation/ImportSimulation.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/ImportSimulation.ts#L29)

Steps needed to perform the refinance

#### Implementation of

[`IImportSimulation`](../interfaces/IImportSimulation.md).[`steps`](../interfaces/IImportSimulation.md#steps)

***

### targetPosition

```ts
readonly targetPosition: ILendingPosition;
```

Defined in: [sdk/sdk-common/src/simulation/implementation/ImportSimulation.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/ImportSimulation.ts#L28)

Simulated target position

#### Implementation of

[`IImportSimulation`](../interfaces/IImportSimulation.md).[`targetPosition`](../interfaces/IImportSimulation.md#targetposition)

***

### type

```ts
readonly type: ImportPosition = SimulationType.ImportPosition;
```

Defined in: [sdk/sdk-common/src/simulation/implementation/ImportSimulation.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/ImportSimulation.ts#L30)

ATTRIBUTES

#### Implementation of

[`IImportSimulation`](../interfaces/IImportSimulation.md).[`type`](../interfaces/IImportSimulation.md#type)

#### Overrides

[`Simulation`](Simulation.md).[`type`](Simulation.md#type)

## Methods

### createFrom()

```ts
static createFrom(params): ImportSimulation;
```

Defined in: [sdk/sdk-common/src/simulation/implementation/ImportSimulation.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/ImportSimulation.ts#L33)

FACTORY

#### Parameters

##### params

[`ImportSimulationParameters`](../type-aliases/ImportSimulationParameters.md)

#### Returns

`ImportSimulation`
