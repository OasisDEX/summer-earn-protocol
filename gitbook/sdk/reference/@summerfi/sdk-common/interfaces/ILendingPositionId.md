# Interface: ILendingPositionId

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPositionId.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPositionId.ts#L14)

## Name

ILendingPositionId

## Description

Represents a position ID for a lending position

## Extends

- [`IPositionId`](IPositionId.md)

## Extended by

- [`IExternalLendingPositionId`](IExternalLendingPositionId.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPositionId.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPositionId.ts#L16)

Signature to differentiate from similar interfaces

#### Inherited from

[`IPositionId`](IPositionId.md).[`[___signature__]`](IPositionId.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPositionId.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPositionId.ts#L15)

Signature to differentiate from similar interfaces

#### Inherited from

```ts
IPositionId.[___signature__]
```

***

### id

```ts
readonly id: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPositionId.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPositionId.ts#L17)

#### Inherited from

[`IPositionId`](IPositionId.md).[`id`](IPositionId.md#id)

***

### type

```ts
readonly type: Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPositionId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPositionId.ts#L19)

Type of the position

#### Overrides

[`IPositionId`](IPositionId.md).[`type`](IPositionId.md#type)
