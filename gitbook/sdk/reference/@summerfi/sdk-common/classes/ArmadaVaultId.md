# Class: ArmadaVaultId

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultId.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultId.ts#L20)

ArmadaVaultId

## See

IArmadaVaultId

## Extends

- `PoolId`

## Implements

- [`IArmadaVaultId`](../interfaces/IArmadaVaultId.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultId.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultId.ts#L22)

SIGNATURE

#### Implementation of

[`IArmadaVaultId`](../interfaces/IArmadaVaultId.md).[`[___signature__]`](../interfaces/IArmadaVaultId.md#___signature__-1)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/PoolId.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PoolId.ts#L18)

SIGNATURE

#### Implementation of

```ts
IArmadaVaultId.[___signature__]
```

#### Inherited from

[`LendingPoolId`](LendingPoolId.md).[`[___signature__]`](LendingPoolId.md#___signature__-1)

***

### chainInfo

```ts
readonly chainInfo: IChainInfo;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultId.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultId.ts#L26)

Chain where the fleet is deployed

#### Implementation of

[`IArmadaVaultId`](../interfaces/IArmadaVaultId.md).[`chainInfo`](../interfaces/IArmadaVaultId.md#chaininfo)

***

### fleetAddress

```ts
readonly fleetAddress: IAddress;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultId.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultId.ts#L27)

Address of the fleet commander that gives access to the pool

#### Implementation of

[`IArmadaVaultId`](../interfaces/IArmadaVaultId.md).[`fleetAddress`](../interfaces/IArmadaVaultId.md#fleetaddress)

***

### protocol

```ts
readonly protocol: IArmadaProtocol;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultId.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultId.ts#L28)

Protocol where the pool is

#### Implementation of

[`IArmadaVaultId`](../interfaces/IArmadaVaultId.md).[`protocol`](../interfaces/IArmadaVaultId.md#protocol)

#### Overrides

```ts
PoolId.protocol
```

***

### type

```ts
readonly type: Armada = PoolType.Armada;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultId.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultId.ts#L25)

ATTRIBUTES

#### Implementation of

[`IArmadaVaultId`](../interfaces/IArmadaVaultId.md).[`type`](../interfaces/IArmadaVaultId.md#type)

#### Overrides

```ts
PoolId.type
```

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/implementation/PoolId.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PoolId.ts#L32)

#### Returns

`string`

#### See

IPrintable.toString

#### Inherited from

```ts
PoolId.toString
```

***

### createFrom()

```ts
static createFrom(params): ArmadaVaultId;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultId.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultId.ts#L31)

FACTORY

#### Parameters

##### params

[`ArmadaVaultIdParameters`](../type-aliases/ArmadaVaultIdParameters.md)

#### Returns

`ArmadaVaultId`
