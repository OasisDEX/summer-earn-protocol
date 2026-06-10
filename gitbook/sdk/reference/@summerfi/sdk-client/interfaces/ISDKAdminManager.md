# Interface: ISDKAdminManager

Defined in: [sdk/sdk-client/src/interfaces/ISDKAdminManager.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKAdminManager.ts#L14)

SDKManager is the main entry point for interacting with the SDK in the client side

It contains all the available services that can be used to interact with the SDK

## Properties

### armada

```ts
readonly armada: IArmadaManagerClient;
```

Defined in: [sdk/sdk-client/src/interfaces/ISDKAdminManager.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKAdminManager.ts#L22)

Armada Manager for interacting with the Armada protocol

***

### chains

```ts
readonly chains: IChainsManagerClient;
```

Defined in: [sdk/sdk-client/src/interfaces/ISDKAdminManager.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKAdminManager.ts#L16)

Chains Manager for interacting with the different chains supported in the SDK

***

### intentSwaps

```ts
readonly intentSwaps: IIntentSwapClient;
```

Defined in: [sdk/sdk-client/src/interfaces/ISDKAdminManager.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKAdminManager.ts#L28)

Intent Swap Client for interacting with CoW Protocol intent swaps

***

### oracle

```ts
readonly oracle: IOracleManagerClient;
```

Defined in: [sdk/sdk-client/src/interfaces/ISDKAdminManager.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKAdminManager.ts#L26)

Swap Manager for interacting with the swaps

***

### swaps

```ts
readonly swaps: ISwapManagerClient;
```

Defined in: [sdk/sdk-client/src/interfaces/ISDKAdminManager.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKAdminManager.ts#L24)

Swap Manager for interacting with the swaps

***

### tokens

```ts
readonly tokens: ITokensManagerClient2;
```

Defined in: [sdk/sdk-client/src/interfaces/ISDKAdminManager.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKAdminManager.ts#L18)

Tokens Manager for interacting with the different tokens supported in the SDK

***

### users

```ts
readonly users: IUsersManager;
```

Defined in: [sdk/sdk-client/src/interfaces/ISDKAdminManager.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKAdminManager.ts#L20)

Users Manager for retrieving information about a user
