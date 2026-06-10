# Interface: IImportSimulation

Defined in: [sdk/sdk-common/src/simulation/interfaces/IImportSimulation.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/IImportSimulation.ts#L23)

IImportSimulation

## Description

Simulation result of an import operation

## Extends

- [`ISimulation`](ISimulation.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/IImportSimulation.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/IImportSimulation.ts#L25)

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
readonly sourcePosition: IExternalLendingPosition;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/IImportSimulation.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/IImportSimulation.ts#L27)

Original position that will be refinanced

***

### steps

```ts
readonly steps: Steps[];
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/IImportSimulation.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/IImportSimulation.ts#L31)

Steps needed to perform the refinance

***

### targetPosition

```ts
readonly targetPosition: ILendingPosition;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/IImportSimulation.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/IImportSimulation.ts#L29)

Simulated target position

***

### type

```ts
readonly type: ImportPosition;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/IImportSimulation.ts:34](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/IImportSimulation.ts#L34)

The type of the simulation

#### Overrides

[`ISimulation`](ISimulation.md).[`type`](ISimulation.md#type)
