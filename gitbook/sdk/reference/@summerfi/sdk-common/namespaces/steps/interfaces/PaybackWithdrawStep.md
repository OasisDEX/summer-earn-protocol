# Interface: PaybackWithdrawStep

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:53](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L53)

## Extends

- [`Step`](Step.md)\<[`PaybackWithdraw`](../../../enumerations/SimulationSteps.md#paybackwithdraw), \{
  `paybackAmount`: [`ReferenceableField`](../../../type-aliases/ReferenceableField.md)\<[`ITokenAmount`](../../../interfaces/ITokenAmount.md)\>;
  `position`: [`ILendingPosition`](../../../interfaces/ILendingPosition.md);
  `withdrawAmount`: [`ITokenAmount`](../../../interfaces/ITokenAmount.md);
  `withdrawTargetType`: [`TokenTransferTargetType`](../../../enumerations/TokenTransferTargetType.md);
\}, \{
  `paybackAmount`: [`ITokenAmount`](../../../interfaces/ITokenAmount.md);
  `withdrawAmount`: [`ITokenAmount`](../../../interfaces/ITokenAmount.md);
\}\>

## Properties

### inputs

```ts
inputs: object;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L20)

#### paybackAmount

```ts
paybackAmount: ReferenceableField<ITokenAmount>;
```

#### position

```ts
position: ILendingPosition;
```

#### withdrawAmount

```ts
withdrawAmount: ITokenAmount;
```

#### withdrawTargetType

```ts
withdrawTargetType: TokenTransferTargetType;
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
outputs: object;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L21)

#### paybackAmount

```ts
paybackAmount: ITokenAmount;
```

#### withdrawAmount

```ts
withdrawAmount: ITokenAmount;
```

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
type: PaybackWithdraw;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L18)

#### Inherited from

[`Step`](Step.md).[`type`](Step.md#type)
