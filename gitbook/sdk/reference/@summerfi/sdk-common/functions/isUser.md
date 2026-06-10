# Function: isUser()

```ts
function isUser(maybeUser, returnedErrors?): maybeUser is IUser;
```

Defined in: [sdk/sdk-common/src/user/interfaces/IUser.ts:41](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/user/interfaces/IUser.ts#L41)

Type guard for IUser

## Parameters

### maybeUser

`unknown`

Object to be checked

### returnedErrors?

`string`[]

## Returns

`maybeUser is IUser`

true if the object is an IUser
