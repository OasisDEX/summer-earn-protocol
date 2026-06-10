# Class: RefinanceSimulation

Defined in: [sdk/sdk-common/src/simulation/implementation/RefinanceSimulation.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/RefinanceSimulation.ts#L22)

## Name

RefinanceSimulation

## See

IRefinanceSimulation

## Extends

- [`Simulation`](Simulation.md)

## Implements

- [`IRefinanceSimulation`](../interfaces/IRefinanceSimulation.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/simulation/implementation/RefinanceSimulation.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/RefinanceSimulation.ts#L24)

SIGNATURE

#### Implementation of

[`IRefinanceSimulation`](../interfaces/IRefinanceSimulation.md).[`[___signature__]`](../interfaces/IRefinanceSimulation.md#___signature__-1)

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
IRefinanceSimulation.[___signature__]
```

#### Inherited from

```ts
Simulation.[___signature__]
```

***

### sourcePosition

```ts
readonly sourcePosition: ILendingPosition;
```

Defined in: [sdk/sdk-common/src/simulation/implementation/RefinanceSimulation.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/RefinanceSimulation.ts#L27)

ATTRIBUTES

#### Implementation of

[`IRefinanceSimulation`](../interfaces/IRefinanceSimulation.md).[`sourcePosition`](../interfaces/IRefinanceSimulation.md#sourceposition)

***

### steps

```ts
readonly steps: Steps[];
```

Defined in: [sdk/sdk-common/src/simulation/implementation/RefinanceSimulation.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/RefinanceSimulation.ts#L30)

Steps needed to perform the refinance

#### Implementation of

[`IRefinanceSimulation`](../interfaces/IRefinanceSimulation.md).[`steps`](../interfaces/IRefinanceSimulation.md#steps)

***

### swaps

```ts
readonly swaps: SimulatedSwapData[];
```

Defined in: [sdk/sdk-common/src/simulation/implementation/RefinanceSimulation.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/RefinanceSimulation.ts#L29)

The details of any swaps required as part of the simulation

#### Implementation of

[`IRefinanceSimulation`](../interfaces/IRefinanceSimulation.md).[`swaps`](../interfaces/IRefinanceSimulation.md#swaps)

***

### targetPosition

```ts
readonly targetPosition: ILendingPosition;
```

Defined in: [sdk/sdk-common/src/simulation/implementation/RefinanceSimulation.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/RefinanceSimulation.ts#L28)

Simulated target position

#### Implementation of

[`IRefinanceSimulation`](../interfaces/IRefinanceSimulation.md).[`targetPosition`](../interfaces/IRefinanceSimulation.md#targetposition)

***

### type

```ts
readonly type: Refinance = SimulationType.Refinance;
```

Defined in: [sdk/sdk-common/src/simulation/implementation/RefinanceSimulation.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/RefinanceSimulation.ts#L31)

ATTRIBUTES

#### Implementation of

[`IRefinanceSimulation`](../interfaces/IRefinanceSimulation.md).[`type`](../interfaces/IRefinanceSimulation.md#type)

#### Overrides

[`Simulation`](Simulation.md).[`type`](Simulation.md#type)

## Methods

### createFrom()

```ts
static createFrom(params): RefinanceSimulation;
```

Defined in: [sdk/sdk-common/src/simulation/implementation/RefinanceSimulation.ts:34](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/RefinanceSimulation.ts#L34)

FACTORY

#### Parameters

##### params

[`RefinanceSimulationParameters`](../type-aliases/RefinanceSimulationParameters.md)

#### Returns

`RefinanceSimulation`
