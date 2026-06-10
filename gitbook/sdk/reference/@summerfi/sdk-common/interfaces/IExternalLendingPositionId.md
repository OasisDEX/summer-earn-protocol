# Interface: IExternalLendingPositionId

Defined in: [sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPositionId.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPositionId.ts#L23)

IExternalPositionId

## Description

Identifier for an external position to the Summer system

## Extends

- [`IExternalLendingPositionIdData`](../type-aliases/IExternalLendingPositionIdData.md).[`ILendingPositionId`](ILendingPositionId.md).[`IPrintable`](IPrintable.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPositionId.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPositionId.ts#L26)

Signature used to differentiate it from similar interfaces

#### Inherited from

[`ILendingPositionId`](ILendingPositionId.md).[`[___signature__]`](ILendingPositionId.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPositionId.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPositionId.ts#L16)

Signature to differentiate from similar interfaces

#### Inherited from

```ts
ILendingPositionId.[___signature__]
```

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPositionId.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPositionId.ts#L15)

Signature to differentiate from similar interfaces

#### Inherited from

```ts
ILendingPositionId.[___signature__]
```

***

### address

```ts
readonly address: IAddress;
```

Defined in: [sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPositionId.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPositionId.ts#L30)

Address of the owner of the position

#### Overrides

```ts
IExternalLendingPositionIdData.address
```

***

### externalType

```ts
readonly externalType: ExternalLendingPositionType;
```

Defined in: [sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPositionId.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPositionId.ts#L28)

Type of the position

#### Overrides

```ts
IExternalLendingPositionIdData.externalType
```

***

### id

```ts
readonly id: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPositionId.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPositionId.ts#L26)

#### Inherited from

[`ILendingPositionId`](ILendingPositionId.md).[`id`](ILendingPositionId.md#id)

***

### protocolId

```ts
readonly protocolId: ILendingPositionId;
```

Defined in: [sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPositionId.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPositionId.ts#L32)

ID of the lending protocol

#### Overrides

```ts
IExternalLendingPositionIdData.protocolId
```

***

### type

```ts
readonly type: Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPositionId.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPositionId.ts#L27)

Type of the position

#### Inherited from

[`ILendingPositionId`](ILendingPositionId.md).[`type`](ILendingPositionId.md#type)

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrintable.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrintable.ts#L15)

#### Returns

`string`

string

The string representation should have enough info to debug the object

#### Name

toString

#### Description

Returns a string representation of the object

#### Inherited from

[`IPrintable`](IPrintable.md).[`toString`](IPrintable.md#tostring)
