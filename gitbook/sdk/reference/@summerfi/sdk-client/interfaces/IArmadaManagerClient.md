# Interface: IArmadaManagerClient

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClient.ts:11](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClient.ts#L11)

IArmadaManagerClient

## Description

Interface of the FleetCommander manager for the SDK Client. Allows to instantiate
             FleetCommanders to interact with them

## Properties

### accessControl

```ts
accessControl: IArmadaManagerClientAccessControl;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClient.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClient.ts#L17)

Access Control API for the Armada protocol - role-based access control operations

***

### admin

```ts
admin: IArmadaManagerAdminClient;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClient.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClient.ts#L15)

Admin API for the Armada protocol - consolidated administrative operations

***

### dca

```ts
dca: IArmadaManagerDCAClient;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClient.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClient.ts#L19)

DCA API for Armada recurring buy orders

***

### users

```ts
users: IArmadaManagerUsersClient;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClient.ts:13](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClient.ts#L13)

Users API for the Armada protocol
