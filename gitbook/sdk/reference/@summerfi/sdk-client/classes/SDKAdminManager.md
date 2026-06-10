# Class: SDKAdminManager

Defined in: [sdk/sdk-client/src/implementation/SDKAdminManager.ts:12](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/SDKAdminManager.ts#L12)

## See

ISDKAdminManager

## Implements

- [`ISDKAdminManager`](../interfaces/ISDKAdminManager.md)

## Constructors

### Constructor

```ts
new SDKAdminManager(params): SDKAdminManager;
```

Defined in: [sdk/sdk-client/src/implementation/SDKAdminManager.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/SDKAdminManager.ts#L21)

#### Parameters

##### params

###### rpcClient

`TRPCClient`

#### Returns

`SDKAdminManager`

## Properties

### armada

```ts
readonly armada: ArmadaManagerClient;
```

Defined in: [sdk/sdk-client/src/implementation/SDKAdminManager.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/SDKAdminManager.ts#L16)

Armada Manager for interacting with the Armada protocol

#### Implementation of

[`ISDKAdminManager`](../interfaces/ISDKAdminManager.md).[`armada`](../interfaces/ISDKAdminManager.md#armada)

***

### chains

```ts
readonly chains: ChainsManagerClient;
```

Defined in: [sdk/sdk-client/src/implementation/SDKAdminManager.ts:13](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/SDKAdminManager.ts#L13)

Chains Manager for interacting with the different chains supported in the SDK

#### Implementation of

[`ISDKAdminManager`](../interfaces/ISDKAdminManager.md).[`chains`](../interfaces/ISDKAdminManager.md#chains)

***

### intentSwaps

```ts
readonly intentSwaps: IntentSwapClient;
```

Defined in: [sdk/sdk-client/src/implementation/SDKAdminManager.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/SDKAdminManager.ts#L19)

Intent Swap Client for interacting with CoW Protocol intent swaps

#### Implementation of

[`ISDKAdminManager`](../interfaces/ISDKAdminManager.md).[`intentSwaps`](../interfaces/ISDKAdminManager.md#intentswaps)

***

### oracle

```ts
readonly oracle: OracleManagerClient;
```

Defined in: [sdk/sdk-client/src/implementation/SDKAdminManager.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/SDKAdminManager.ts#L18)

Swap Manager for interacting with the swaps

#### Implementation of

[`ISDKAdminManager`](../interfaces/ISDKAdminManager.md).[`oracle`](../interfaces/ISDKAdminManager.md#oracle)

***

### swaps

```ts
readonly swaps: SwapManagerClient;
```

Defined in: [sdk/sdk-client/src/implementation/SDKAdminManager.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/SDKAdminManager.ts#L17)

Swap Manager for interacting with the swaps

#### Implementation of

[`ISDKAdminManager`](../interfaces/ISDKAdminManager.md).[`swaps`](../interfaces/ISDKAdminManager.md#swaps)

***

### tokens

```ts
readonly tokens: TokensManagerClient2;
```

Defined in: [sdk/sdk-client/src/implementation/SDKAdminManager.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/SDKAdminManager.ts#L14)

Tokens Manager for interacting with the different tokens supported in the SDK

#### Implementation of

[`ISDKAdminManager`](../interfaces/ISDKAdminManager.md).[`tokens`](../interfaces/ISDKAdminManager.md#tokens)

***

### users

```ts
readonly users: UsersManager;
```

Defined in: [sdk/sdk-client/src/implementation/SDKAdminManager.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/SDKAdminManager.ts#L15)

Users Manager for retrieving information about a user

#### Implementation of

[`ISDKAdminManager`](../interfaces/ISDKAdminManager.md).[`users`](../interfaces/ISDKAdminManager.md#users)
