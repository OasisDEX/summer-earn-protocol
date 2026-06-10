# Interface: FlashloanStep

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L25)

## Extends

- [`Step`](Step.md)\<[`Flashloan`](../../../enumerations/SimulationSteps.md#flashloan), \{
  `amount`: [`ITokenAmount`](../../../interfaces/ITokenAmount.md);
  `provider`: [`FlashloanProvider`](../../../enumerations/FlashloanProvider.md);
\}\>

## Properties

### inputs

```ts
inputs: object;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L20)

#### amount

```ts
amount: ITokenAmount;
```

#### provider

```ts
provider: FlashloanProvider;
```

#### Inherited from

[`Step`](Step.md).[`inputs`](Step.md#inputs)

***

### name

```ts
name: string;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L19)

#### Inherited from

[`Step`](Step.md).[`name`](Step.md#name)

***

### outputs

```ts
outputs: undefined;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L21)

#### Inherited from

[`Step`](Step.md).[`outputs`](Step.md#outputs)

***

### skip?

```ts
optional skip: boolean;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L22)

#### Inherited from

[`Step`](Step.md).[`skip`](Step.md#skip)

***

### type

```ts
type: Flashloan;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L18)

#### Inherited from

[`Step`](Step.md).[`type`](Step.md#type)
