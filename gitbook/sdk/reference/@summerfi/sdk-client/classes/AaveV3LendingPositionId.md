# Class: AaveV3LendingPositionId

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPositionId.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPositionId.ts#L17)

AaveV3PositionId

## See

IAaveV3LendingPositionIdData

## Extends

- [`LendingPositionId`](LendingPositionId.md)

## Implements

- `IAaveV3LendingPositionId`

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPositionId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPositionId.ts#L19)

SIGNATURE

#### Implementation of

```ts
IAaveV3LendingPositionId.[___signature__]
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
IAaveV3LendingPositionId.[___signature__]
```

#### Inherited from

[`LendingPositionId`](LendingPositionId.md).[`[___signature__]`](LendingPositionId.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/PositionId.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PositionId.ts#L16)

SIGNATURE

#### Implementation of

```ts
IAaveV3LendingPositionId.[___signature__]
```

#### Inherited from

[`ExternalLendingPositionId`](ExternalLendingPositionId.md).[`[___signature__]`](ExternalLendingPositionId.md#___signature__-2)

***

### id

```ts
readonly id: string;
```

Defined in: [sdk/sdk-common/src/common/implementation/PositionId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PositionId.ts#L19)

ATTRIBUTES

#### Implementation of

```ts
IAaveV3LendingPositionId.id
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
IAaveV3LendingPositionId.type
```

#### Inherited from

[`LendingPositionId`](LendingPositionId.md).[`type`](LendingPositionId.md#type)

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
static createFrom(params): AaveV3LendingPositionId;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPositionId.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPositionId.ts#L22)

FACTORY

#### Parameters

##### params

`AaveV3LendingPositionIdParameters`

#### Returns

`AaveV3LendingPositionId`
