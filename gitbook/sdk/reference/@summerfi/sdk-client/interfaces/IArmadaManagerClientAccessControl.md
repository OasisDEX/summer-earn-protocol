# Interface: IArmadaManagerClientAccessControl

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts#L15)

## Name

IArmadaManagerClientAccessControl

## Description

Interface for the Armada Manager Access Control client - handles role-based access control operations

## Methods

### getAllAddressesWithContractSpecificRole()

```ts
getAllAddressesWithContractSpecificRole(params): Promise<`0x${string}`[]>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts:142](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts#L142)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### contractAddress

[`IAddress`](IAddress.md)

###### role

[`ContractSpecificRoleName`](../enumerations/ContractSpecificRoleName.md)

#### Returns

`Promise`\<`` `0x${string}` ``[]\>

Promise<AddressValue[]> Array of addresses that have the role

#### Name

getAllAddressesWithContractSpecificRole

#### Description

Gets all addresses that currently have a specific contract-specific role

***

### getAllAddressesWithGlobalRole()

```ts
getAllAddressesWithGlobalRole(params): Promise<`0x${string}`[]>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts:127](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts#L127)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### role

[`GlobalRoles`](../enumerations/GlobalRoles.md)

#### Returns

`Promise`\<`` `0x${string}` ``[]\>

Promise<AddressValue[]> Array of addresses that have the role

#### Name

getAllAddressesWithGlobalRole

#### Description

Gets all addresses that currently have a specific global protocol role

***

### getAllRoles()

```ts
getAllRoles(params): Promise<RolesResponse>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts:256](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts#L256)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### first?

`number`

###### name?

`string`

###### owner?

`` `0x${string}` ``

###### skip?

`number`

###### targetContract?

`` `0x${string}` ``

#### Returns

`Promise`\<[`RolesResponse`](../type-aliases/RolesResponse.md)\>

Promise with array of role objects containing id, name, owner, targetContract, and institution

#### Name

getAllRoles

#### Description

Gets all roles for a given chainId with pagination and filtering support

***

### grantContractSpecificRole()

```ts
grantContractSpecificRole(params): Promise<TransactionInfo>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts:93](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts#L93)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### contractAddress

[`IAddress`](IAddress.md)

###### role

[`ContractSpecificRoleName`](../enumerations/ContractSpecificRoleName.md)

###### targetAddress

[`IAddress`](IAddress.md)

#### Returns

`Promise`\<[`TransactionInfo`](TransactionInfo.md)\>

Promise<TransactionInfo> The transaction information

#### Name

grantContractSpecificRole

#### Description

Grants a contract-specific role to an address

***

### grantGlobalRole()

```ts
grantGlobalRole(params): Promise<TransactionInfo>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts:60](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts#L60)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### role

[`GlobalRoles`](../enumerations/GlobalRoles.md)

###### targetAddress

[`IAddress`](IAddress.md)

#### Returns

`Promise`\<[`TransactionInfo`](TransactionInfo.md)\>

Promise<TransactionInfo> The transaction information

#### Name

grantGlobalRole

#### Description

Grants a global protocol role to an address

***

### hasContractSpecificRole()

```ts
hasContractSpecificRole(params): Promise<boolean>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts:43](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts#L43)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### contractAddress

[`IAddress`](IAddress.md)

###### role

[`ContractSpecificRoleName`](../enumerations/ContractSpecificRoleName.md)

###### targetAddress

[`IAddress`](IAddress.md)

#### Returns

`Promise`\<`boolean`\>

Promise<boolean> True if the target address has the role

#### Name

hasContractSpecificRole

#### Description

Checks if an address has a specific contract-specific role

***

### hasGlobalRole()

```ts
hasGlobalRole(params): Promise<boolean>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts#L26)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### role

[`GlobalRoles`](../enumerations/GlobalRoles.md)

###### targetAddress

[`IAddress`](IAddress.md)

#### Returns

`Promise`\<`boolean`\>

Promise<boolean> True if the address has the role

#### Name

hasGlobalRole

#### Description

Checks if an address has a specific global protocol role

***

### isWhitelisted()

```ts
isWhitelisted(params): Promise<boolean>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts:158](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts#L158)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### fleetCommanderAddress

`` `0x${string}` ``

###### targetAddress

`` `0x${string}` ``

#### Returns

`Promise`\<`boolean`\>

Promise<boolean> True if the address is whitelisted

#### Name

isWhitelisted

#### Description

Checks if an address is whitelisted in the FleetCommander contract

***

### isWhitelistedAQ()

```ts
isWhitelistedAQ(params): Promise<boolean>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts:209](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts#L209)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### targetAddress

`` `0x${string}` ``

#### Returns

`Promise`\<`boolean`\>

Promise<boolean> True if the address is whitelisted

#### Name

isWhitelistedAQ

#### Description

Checks if an address is whitelisted in the AdmiralsQuarters contract

***

### revokeContractSpecificRole()

```ts
revokeContractSpecificRole(params): Promise<TransactionInfo>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts:111](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts#L111)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### contractAddress

[`IAddress`](IAddress.md)

###### role

[`ContractSpecificRoleName`](../enumerations/ContractSpecificRoleName.md)

###### targetAddress

[`IAddress`](IAddress.md)

#### Returns

`Promise`\<[`TransactionInfo`](TransactionInfo.md)\>

Promise<TransactionInfo> The transaction information

#### Name

revokeContractSpecificRole

#### Description

Revokes a contract-specific role from an address

***

### revokeGlobalRole()

```ts
revokeGlobalRole(params): Promise<TransactionInfo>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts:76](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts#L76)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### role

[`GlobalRoles`](../enumerations/GlobalRoles.md)

###### targetAddress

[`IAddress`](IAddress.md)

#### Returns

`Promise`\<[`TransactionInfo`](TransactionInfo.md)\>

Promise<TransactionInfo> The transaction information

#### Name

revokeGlobalRole

#### Description

Revokes a global protocol role from an address

***

### setWhitelisted()

```ts
setWhitelisted(params): Promise<TransactionInfo>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts:175](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts#L175)

#### Parameters

##### params

###### allowed

`boolean`

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### fleetCommanderAddress

`` `0x${string}` ``

###### targetAddress

`` `0x${string}` ``

#### Returns

`Promise`\<[`TransactionInfo`](TransactionInfo.md)\>

Promise<TransactionInfo> The transaction information

#### Name

setWhitelisted

#### Description

Sets the whitelist status for an address in the FleetCommander contract

***

### setWhitelistedAQ()

```ts
setWhitelistedAQ(params): Promise<TransactionInfo>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts:221](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts#L221)

#### Parameters

##### params

###### allowed

`boolean`

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### targetAddress

`` `0x${string}` ``

#### Returns

`Promise`\<[`TransactionInfo`](TransactionInfo.md)\>

Promise<TransactionInfo> The transaction information

#### Name

setWhitelistedAQ

#### Description

Sets the whitelist status for an address in the AdmiralsQuarters contract

***

### setWhitelistedBatch()

```ts
setWhitelistedBatch(params): Promise<TransactionInfo>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts:193](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts#L193)

#### Parameters

##### params

###### allowed

`boolean`[]

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### fleetCommanderAddress

`` `0x${string}` ``

###### targetAddresses

`` `0x${string}` ``[]

#### Returns

`Promise`\<[`TransactionInfo`](TransactionInfo.md)\>

Promise<TransactionInfo> The transaction information

#### Name

setWhitelistedBatch

#### Description

Sets the whitelist status for multiple addresses in the FleetCommander contract

***

### setWhitelistedBatchAQ()

```ts
setWhitelistedBatchAQ(params): Promise<TransactionInfo>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts:237](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerClientAccessControl.ts#L237)

#### Parameters

##### params

###### allowed

`boolean`[]

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### targetAddresses

`` `0x${string}` ``[]

#### Returns

`Promise`\<[`TransactionInfo`](TransactionInfo.md)\>

Promise<TransactionInfo> The transaction information

#### Name

setWhitelistedBatchAQ

#### Description

Sets the whitelist status for multiple addresses in the AdmiralsQuarters contract
