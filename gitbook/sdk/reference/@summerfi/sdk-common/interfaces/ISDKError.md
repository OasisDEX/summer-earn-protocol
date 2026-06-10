# Interface: ISDKError

Defined in: [sdk/sdk-common/src/common/interfaces/ISDKError.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ISDKError.ts#L14)

## Name

ISDKError

## Description

Represents a custom error of the SDK

## Extends

- [`ISDKErrorData`](../type-aliases/ISDKErrorData.md).[`IPrintable`](IPrintable.md)

## Extended by

- [`ISwapError`](ISwapError.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ISDKError.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ISDKError.ts#L16)

Signature to differentiate from similar interfaces

***

### message

```ts
readonly message: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ISDKError.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ISDKError.ts#L22)

Free form debug message, used to debug the issue through the console

#### Overrides

```ts
ISDKErrorData.message
```

***

### reason

```ts
readonly reason: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ISDKError.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ISDKError.ts#L20)

Free form reason message, used to provide a short description of the problem

#### Overrides

```ts
ISDKErrorData.reason
```

***

### type

```ts
readonly type: SDKErrorType;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ISDKError.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ISDKError.ts#L18)

Error type main category

#### Overrides

```ts
ISDKErrorData.type
```

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

[`IPrintable`](IPrintable.md).[`toString`](IPrintable.md#tostring)
