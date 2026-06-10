# Interface: IPositionId

Defined in: [sdk/sdk-common/src/common/interfaces/IPositionId.ts:13](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPositionId.ts#L13)

## Name

IPositionId

## Description

Represents a unique identifier for a position in the Summer system

## Extends

- [`IPositionIdData`](../type-aliases/IPositionIdData.md)

## Extended by

- [`IArmadaPositionId`](IArmadaPositionId.md)
- [`ILendingPositionId`](ILendingPositionId.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPositionId.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPositionId.ts#L15)

Signature to differentiate from similar interfaces

***

### id

```ts
readonly id: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPositionId.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPositionId.ts#L17)

#### Overrides

```ts
IPositionIdData.id
```

***

### type

```ts
readonly type: PositionType;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPositionId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPositionId.ts#L19)

Type of the position

#### Overrides

```ts
IPositionIdData.type
```
