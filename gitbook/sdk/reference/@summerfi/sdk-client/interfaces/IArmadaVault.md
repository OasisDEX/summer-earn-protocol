# Interface: IArmadaVault

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVault.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVault.ts#L15)

IArmadaVault

## Description

Interface for an ID of an Armada Protocol vault (fleet)

## Extends

- [`IPool`](IPool.md).[`IArmadaVaultData`](../type-aliases/IArmadaVaultData.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVault.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVault.ts#L17)

Signature used to differentiate it from similar interfaces

#### Inherited from

[`IPool`](IPool.md).[`[___signature__]`](IPool.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPool.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPool.ts#L20)

Signature to differentiate from similar interfaces

#### Inherited from

```ts
IPool.[___signature__]
```

***

### id

```ts
readonly id: IArmadaVaultId;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVault.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVault.ts#L19)

ID of the vault

#### Overrides

[`IPool`](IPool.md).[`id`](IPool.md#id)

***

### type

```ts
readonly type: Armada;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVault.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVault.ts#L22)

Type of the pool

#### Overrides

[`IPool`](IPool.md).[`type`](IPool.md#type)

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

[`IPool`](IPool.md).[`toString`](IPool.md#tostring)
