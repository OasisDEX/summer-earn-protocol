# Interface: ISDKManager

Defined in: [sdk/sdk-client/src/interfaces/ISDKManager.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKManager.ts#L16)

SDKManager is the main entry point for interacting with the SDK in the client side

It contains all the available services that can be used to interact with the SDK

## Properties

### armada

```ts
readonly armada: IArmadaManagerClient;
```

Defined in: [sdk/sdk-client/src/interfaces/ISDKManager.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKManager.ts#L28)

Armada Manager for interacting with the Armada protocol

***

### chains

```ts
readonly chains: IChainsManagerClient;
```

Defined in: [sdk/sdk-client/src/interfaces/ISDKManager.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKManager.ts#L20)

Chains Manager for interacting with the different chains supported in the SDK

***

### intentSwaps

```ts
readonly intentSwaps: IIntentSwapClient;
```

Defined in: [sdk/sdk-client/src/interfaces/ISDKManager.ts:34](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKManager.ts#L34)

Intent Swap Client for interacting with CoW Protocol intent swaps

***

### oracle

```ts
readonly oracle: IOracleManagerClient;
```

Defined in: [sdk/sdk-client/src/interfaces/ISDKManager.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKManager.ts#L32)

Swap Manager for interacting with the swaps

***

### portfolio

```ts
readonly portfolio: IPortfolioManager;
```

Defined in: [sdk/sdk-client/src/interfaces/ISDKManager.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKManager.ts#L26)

Portfolio Manager for retrieving information about a user's portfolio

***

### simulator

```ts
readonly simulator: ISimulationManager;
```

Defined in: [sdk/sdk-client/src/interfaces/ISDKManager.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKManager.ts#L18)

Simulator for all the different operations supported in the SDK

***

### swaps

```ts
readonly swaps: ISwapManagerClient;
```

Defined in: [sdk/sdk-client/src/interfaces/ISDKManager.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKManager.ts#L30)

Swap Manager for interacting with the swaps

***

### tokens

```ts
readonly tokens: ITokensManagerClient2;
```

Defined in: [sdk/sdk-client/src/interfaces/ISDKManager.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKManager.ts#L22)

Tokens Manager for interacting with the different tokens supported in the SDK

***

### users

```ts
readonly users: IUsersManager;
```

Defined in: [sdk/sdk-client/src/interfaces/ISDKManager.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ISDKManager.ts#L24)

Users Manager for retrieving information about a user
