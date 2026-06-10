# Abstract Class: Simulation

Defined in: [sdk/sdk-common/src/simulation/implementation/Simulation.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/Simulation.ts#L14)

## Name

Simulation

## See

ISimulation

## Extended by

- [`ImportSimulation`](ImportSimulation.md)
- [`RefinanceSimulation`](RefinanceSimulation.md)

## Implements

- [`ISimulation`](../interfaces/ISimulation.md)

## Constructors

### Constructor

```ts
protected new Simulation(_): Simulation;
```

Defined in: [sdk/sdk-common/src/simulation/implementation/Simulation.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/Simulation.ts#L22)

SEALED CONSTRUCTOR

#### Parameters

##### \_

[`SimulationParams`](../type-aliases/SimulationParams.md)

#### Returns

`Simulation`

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/simulation/implementation/Simulation.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/Simulation.ts#L16)

SIGNATURE

#### Implementation of

[`ISimulation`](../interfaces/ISimulation.md).[`[___signature__]`](../interfaces/ISimulation.md#___signature__)

***

### type

```ts
abstract readonly type: SimulationType;
```

Defined in: [sdk/sdk-common/src/simulation/implementation/Simulation.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/implementation/Simulation.ts#L19)

ATTRIBUTES

#### Implementation of

[`ISimulation`](../interfaces/ISimulation.md).[`type`](../interfaces/ISimulation.md#type)
