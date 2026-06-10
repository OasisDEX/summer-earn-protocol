# Class: ArmadaVault

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVault.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVault.ts#L17)

ArmadaVault

## See

IArmadaVault

## Extends

- `Pool`

## Implements

- [`IArmadaVault`](../interfaces/IArmadaVault.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVault.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVault.ts#L19)

SIGNATURE

#### Implementation of

[`IArmadaVault`](../interfaces/IArmadaVault.md).[`[___signature__]`](../interfaces/IArmadaVault.md#___signature__-1)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/Pool.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Pool.ts#L18)

SIGNATURE

#### Implementation of

```ts
IArmadaVault.[___signature__]
```

#### Inherited from

[`LendingPool`](LendingPool.md).[`[___signature__]`](LendingPool.md#___signature__-1)

***

### id

```ts
readonly id: IArmadaVaultId;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVault.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVault.ts#L23)

ID of the vault

#### Implementation of

[`IArmadaVault`](../interfaces/IArmadaVault.md).[`id`](../interfaces/IArmadaVault.md#id)

#### Overrides

```ts
Pool.id
```

***

### type

```ts
readonly type: Armada = PoolType.Armada;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVault.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVault.ts#L22)

ATTRIBUTES

#### Implementation of

[`IArmadaVault`](../interfaces/IArmadaVault.md).[`type`](../interfaces/IArmadaVault.md#type)

#### Overrides

```ts
Pool.type
```

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/implementation/Pool.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Pool.ts#L32)

#### Returns

`string`

#### See

IPrintable.toString

#### Implementation of

[`IArmadaVault`](../interfaces/IArmadaVault.md).[`toString`](../interfaces/IArmadaVault.md#tostring)

#### Inherited from

```ts
Pool.toString
```

***

### createFrom()

```ts
static createFrom(params): ArmadaVault;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVault.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVault.ts#L26)

FACTORY

#### Parameters

##### params

[`ArmadaVaultParameters`](../type-aliases/ArmadaVaultParameters.md)

#### Returns

`ArmadaVault`
