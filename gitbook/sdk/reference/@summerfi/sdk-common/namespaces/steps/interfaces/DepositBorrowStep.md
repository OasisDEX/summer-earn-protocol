# Interface: DepositBorrowStep

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:38](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L38)

## Extends

- [`Step`](Step.md)\<[`DepositBorrow`](../../../enumerations/SimulationSteps.md#depositborrow), \{
  `additionalDeposit?`: [`ValueReference`](../../../interfaces/ValueReference.md)\<[`ITokenAmount`](../../../interfaces/ITokenAmount.md)\>;
  `borrowAmount`: [`ReferenceableField`](../../../type-aliases/ReferenceableField.md)\<[`ITokenAmount`](../../../interfaces/ITokenAmount.md)\>;
  `borrowTargetType`: [`TokenTransferTargetType`](../../../enumerations/TokenTransferTargetType.md);
  `depositAmount`: [`ReferenceableField`](../../../type-aliases/ReferenceableField.md)\<[`ITokenAmount`](../../../interfaces/ITokenAmount.md)\>;
  `position`: [`ILendingPosition`](../../../interfaces/ILendingPosition.md);
\}, \{
  `borrowAmount`: [`ITokenAmount`](../../../interfaces/ITokenAmount.md);
  `depositAmount`: [`ITokenAmount`](../../../interfaces/ITokenAmount.md);
\}\>

## Properties

### inputs

```ts
inputs: object;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L20)

#### additionalDeposit?

```ts
optional additionalDeposit: ValueReference<ITokenAmount>;
```

#### borrowAmount

```ts
borrowAmount: ReferenceableField<ITokenAmount>;
```

#### borrowTargetType

```ts
borrowTargetType: TokenTransferTargetType;
```

#### depositAmount

```ts
depositAmount: ReferenceableField<ITokenAmount>;
```

#### position

```ts
position: ILendingPosition;
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

#### borrowAmount

```ts
borrowAmount: ITokenAmount;
```

#### depositAmount

```ts
depositAmount: ITokenAmount;
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
type: DepositBorrow;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L18)

#### Inherited from

[`Step`](Step.md).[`type`](Step.md#type)
