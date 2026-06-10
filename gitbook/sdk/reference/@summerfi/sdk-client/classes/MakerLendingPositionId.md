# Class: MakerLendingPositionId

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPositionId.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPositionId.ts#L18)

MakerPositionId

## See

IMakerLendingPositionIdData

## Extends

- [`LendingPositionId`](LendingPositionId.md)

## Implements

- `IMakerLendingPositionId`

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPositionId.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPositionId.ts#L20)

SIGNATURE

#### Implementation of

```ts
IMakerLendingPositionId.[___signature__]
```

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
IMakerLendingPositionId.[___signature__]
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
IMakerLendingPositionId.[___signature__]
```

#### Inherited from

```ts
LendingPositionId.[___signature__]
```

***

### id

```ts
readonly id: string;
```

Defined in: [sdk/sdk-common/src/common/implementation/PositionId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PositionId.ts#L19)

ATTRIBUTES

#### Implementation of

```ts
IMakerLendingPositionId.id
```

#### Inherited from

[`LendingPositionId`](LendingPositionId.md).[`id`](LendingPositionId.md#id)

***

### type

```ts
readonly type: Lending = PositionType.Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts#L20)

ATTRIBUTES

#### Implementation of

```ts
IMakerLendingPositionId.type
```

#### Inherited from

[`LendingPositionId`](LendingPositionId.md).[`type`](LendingPositionId.md#type)

***

### vaultId

```ts
readonly vaultId: string;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPositionId.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPositionId.ts#L23)

ATTRIBUTES

#### Implementation of

```ts
IMakerLendingPositionId.vaultId
```

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts#L30)

#### Returns

`string`

#### See

IPrintable.toString

#### Inherited from

[`LendingPositionId`](LendingPositionId.md).[`toString`](LendingPositionId.md#tostring)

***

### createFrom()

```ts
static createFrom(params): MakerLendingPositionId;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPositionId.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPositionId.ts#L26)

FACTORY

#### Parameters

##### params

[`MakerLendingPositionIdParameters`](../type-aliases/MakerLendingPositionIdParameters.md)

#### Returns

`MakerLendingPositionId`
