# Function: isSDKError()

```ts
function isSDKError(maybeErrorData): maybeErrorData is Readonly<{ message: string; reason: string; type: SDKErrorType }>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ISDKError.ts:44](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ISDKError.ts#L44)

## Parameters

### maybeErrorData

`unknown`

## Returns

`maybeErrorData is Readonly<{ message: string; reason: string; type: SDKErrorType }>`

true if the object is an ISDKError

## Description

Type guard for ISDKError
