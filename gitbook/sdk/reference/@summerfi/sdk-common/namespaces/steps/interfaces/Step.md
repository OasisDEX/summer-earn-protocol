# Interface: Step\<T, I, O\>

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L17)

## Extended by

- [`FlashloanStep`](FlashloanStep.md)
- [`PullTokenStep`](PullTokenStep.md)
- [`DepositBorrowStep`](DepositBorrowStep.md)
- [`PaybackWithdrawStep`](PaybackWithdrawStep.md)
- [`SkippedStep`](SkippedStep.md)
- [`SwapStep`](SwapStep.md)
- [`ReturnFundsStep`](ReturnFundsStep.md)
- [`RepayFlashloanStep`](RepayFlashloanStep.md)
- [`NewPositionEventStep`](NewPositionEventStep.md)
- [`ImportStep`](ImportStep.md)
- [`OpenPosition`](OpenPosition.md)

## Type Parameters

### T

`T` *extends* [`SimulationSteps`](../../../enumerations/SimulationSteps.md)

### I

`I`

### O

`O` = `undefined`

## Properties

### inputs

```ts
inputs: I;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L20)

***

### name

```ts
name: string;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L19)

***

### outputs

```ts
outputs: O;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L21)

***

### skip?

```ts
optional skip: boolean;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L22)

***

### type

```ts
type: T;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L18)
