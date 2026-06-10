# Interface: ISimulation

Defined in: [sdk/sdk-common/src/simulation/interfaces/ISimulation.ts:13](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/ISimulation.ts#L13)

ISimulation

## Description

Generic simulation interface, defines the simulation type for all simulations

## Extended by

- [`IImportSimulation`](IImportSimulation.md)
- [`IRefinanceSimulation`](IRefinanceSimulation.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/ISimulation.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/ISimulation.ts#L15)

Signature used to differentiate it from similar interfaces

***

### type

```ts
readonly type: SimulationType;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/ISimulation.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/ISimulation.ts#L17)

The type of the simulation
