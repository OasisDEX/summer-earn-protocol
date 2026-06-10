# Class: ExternalLendingPositionId

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPositionId.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPositionId.ts#L21)

## Name

ExternalLendingPositionId

## See

IExternalLendingPositionId

## Extends

- [`LendingPositionId`](LendingPositionId.md)

## Implements

- [`IExternalLendingPositionId`](../interfaces/IExternalLendingPositionId.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPositionId.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPositionId.ts#L26)

SIGNATURE

#### Implementation of

[`IExternalLendingPositionId`](../interfaces/IExternalLendingPositionId.md).[`[___signature__]`](../interfaces/IExternalLendingPositionId.md#___signature__-2)

#### Inherited from

[`LendingPositionId`](LendingPositionId.md).[`[___signature__]`](LendingPositionId.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts#L17)

SIGNATURE

#### Implementation of

```ts
IExternalLendingPositionId.[___signature__]
```

#### Inherited from

```ts
LendingPositionId.[___signature__]
```

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/PositionId.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PositionId.ts#L16)

SIGNATURE

#### Implementation of

```ts
IExternalLendingPositionId.[___signature__]
```

#### Inherited from

```ts
LendingPositionId.[___signature__]
```

***

### address

```ts
readonly address: IAddress;
```

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPositionId.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPositionId.ts#L30)

Address of the owner of the position

#### Implementation of

[`IExternalLendingPositionId`](../interfaces/IExternalLendingPositionId.md).[`address`](../interfaces/IExternalLendingPositionId.md#address)

***

### externalType

```ts
readonly externalType: ExternalLendingPositionType;
```

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPositionId.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPositionId.ts#L29)

ATTRIBUTES

#### Implementation of

[`IExternalLendingPositionId`](../interfaces/IExternalLendingPositionId.md).[`externalType`](../interfaces/IExternalLendingPositionId.md#externaltype)

***

### id

```ts
readonly id: string;
```

Defined in: [sdk/sdk-common/src/common/implementation/PositionId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PositionId.ts#L19)

ATTRIBUTES

#### Implementation of

[`IExternalLendingPositionId`](../interfaces/IExternalLendingPositionId.md).[`id`](../interfaces/IExternalLendingPositionId.md#id)

#### Inherited from

[`LendingPositionId`](LendingPositionId.md).[`id`](LendingPositionId.md#id)

***

### protocolId

```ts
readonly protocolId: ILendingPositionId;
```

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPositionId.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPositionId.ts#L31)

ID of the lending protocol

#### Implementation of

[`IExternalLendingPositionId`](../interfaces/IExternalLendingPositionId.md).[`protocolId`](../interfaces/IExternalLendingPositionId.md#protocolid)

***

### type

```ts
readonly type: Lending = PositionType.Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts#L20)

ATTRIBUTES

#### Implementation of

[`IExternalLendingPositionId`](../interfaces/IExternalLendingPositionId.md).[`type`](../interfaces/IExternalLendingPositionId.md#type)

#### Inherited from

[`LendingPositionId`](LendingPositionId.md).[`type`](LendingPositionId.md#type)

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPositionId.ts:50](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPositionId.ts#L50)

#### Returns

`string`

#### See

IPrintable.toString

#### Implementation of

[`IExternalLendingPositionId`](../interfaces/IExternalLendingPositionId.md).[`toString`](../interfaces/IExternalLendingPositionId.md#tostring)

#### Overrides

[`LendingPositionId`](LendingPositionId.md).[`toString`](LendingPositionId.md#tostring)

***

### createFrom()

```ts
static createFrom(params): ExternalLendingPositionId;
```

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPositionId.ts:34](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPositionId.ts#L34)

FACTORY

#### Parameters

##### params

[`ExternalLendingPositionIdParameters`](../type-aliases/ExternalLendingPositionIdParameters.md)

#### Returns

`ExternalLendingPositionId`
