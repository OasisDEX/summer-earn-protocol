# Interface: IRefinanceSimulation

Defined in: [sdk/sdk-common/src/simulation/interfaces/IRefinanceSimulation.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/IRefinanceSimulation.ts#L20)

IRefinanceSimulation

## Description

Simulation result of a refinance operation

## Extends

- [`ISimulation`](ISimulation.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/IRefinanceSimulation.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/IRefinanceSimulation.ts#L22)

Signature used to differentiate it from similar interfaces

#### Inherited from

[`ISimulation`](ISimulation.md).[`[___signature__]`](ISimulation.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/ISimulation.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/ISimulation.ts#L15)

Signature used to differentiate it from similar interfaces

#### Inherited from

```ts
ISimulation.[___signature__]
```

***

### sourcePosition

```ts
readonly sourcePosition: ILendingPosition;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/IRefinanceSimulation.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/IRefinanceSimulation.ts#L24)

Original position that will be refinanced

***

### steps

```ts
readonly steps: Steps[];
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/IRefinanceSimulation.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/IRefinanceSimulation.ts#L30)

Steps needed to perform the refinance

***

### swaps

```ts
readonly swaps: SimulatedSwapData[];
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/IRefinanceSimulation.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/IRefinanceSimulation.ts#L28)

The details of any swaps required as part of the simulation

***

### targetPosition

```ts
readonly targetPosition: ILendingPosition;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/IRefinanceSimulation.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/IRefinanceSimulation.ts#L26)

Simulated target position

***

### type

```ts
readonly type: Refinance;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/IRefinanceSimulation.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/IRefinanceSimulation.ts#L33)

The type of the simulation

#### Overrides

[`ISimulation`](ISimulation.md).[`type`](ISimulation.md#type)
