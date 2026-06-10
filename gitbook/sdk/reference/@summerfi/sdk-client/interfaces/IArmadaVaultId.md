# Interface: IArmadaVaultId

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultId.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultId.ts#L17)

IArmadaVaultId

## Description

Interface for an ID of an Armada Protocol pool (fleet)

## Extends

- [`IPoolId`](IPoolId.md).[`IArmadaVaultIdData`](../type-aliases/IArmadaVaultIdData.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultId.ts#L19)

Signature used to differentiate it from similar interfaces

#### Inherited from

[`IPoolId`](IPoolId.md).[`[___signature__]`](IPoolId.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPoolId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPoolId.ts#L19)

Signature to differentiate from similar interfaces

#### Inherited from

```ts
IPoolId.[___signature__]
```

***

### chainInfo

```ts
readonly chainInfo: IChainInfo;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultId.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultId.ts#L21)

Chain where the fleet is deployed

#### Overrides

```ts
IArmadaVaultIdData.chainInfo
```

***

### fleetAddress

```ts
readonly fleetAddress: IAddress;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultId.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultId.ts#L23)

Address of the fleet commander that gives access to the pool

#### Overrides

```ts
IArmadaVaultIdData.fleetAddress
```

***

### protocol

```ts
readonly protocol: IArmadaProtocol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultId.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultId.ts#L27)

Protocol where the pool is

#### Overrides

[`IPoolId`](IPoolId.md).[`protocol`](IPoolId.md#protocol)

***

### type

```ts
readonly type: Armada;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultId.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultId.ts#L26)

Pool type

#### Overrides

[`IPoolId`](IPoolId.md).[`type`](IPoolId.md#type)
