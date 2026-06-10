# Interface: ISwapError

Defined in: [sdk/sdk-common/src/swap/interfaces/ISwapError.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/swap/interfaces/ISwapError.ts#L15)

## Name

ISwapError

## Description

Represents a custom error of the SDK for the Swap service

## Extends

- [`ISDKError`](ISDKError.md).[`ISwapErrorData`](../type-aliases/ISwapErrorData.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/swap/interfaces/ISwapError.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/swap/interfaces/ISwapError.ts#L17)

Signature to differentiate from similar interfaces

#### Inherited from

[`ISDKError`](ISDKError.md).[`[___signature__]`](ISDKError.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ISDKError.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ISDKError.ts#L16)

Signature to differentiate from similar interfaces

#### Inherited from

```ts
ISDKError.[___signature__]
```

***

### apiQuery

```ts
readonly apiQuery: string;
```

Defined in: [sdk/sdk-common/src/swap/interfaces/ISwapError.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/swap/interfaces/ISwapError.ts#L22)

Full URL of the API query that generated the error

#### Overrides

```ts
ISwapErrorData.apiQuery
```

***

### message

```ts
readonly message: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ISDKError.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ISDKError.ts#L22)

Free form debug message, used to debug the issue through the console

#### Inherited from

[`ISDKError`](ISDKError.md).[`message`](ISDKError.md#message)

***

### reason

```ts
readonly reason: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ISDKError.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ISDKError.ts#L20)

Free form reason message, used to provide a short description of the problem

#### Inherited from

[`ISDKError`](ISDKError.md).[`reason`](ISDKError.md#reason)

***

### statusCode

```ts
readonly statusCode: number;
```

Defined in: [sdk/sdk-common/src/swap/interfaces/ISwapError.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/swap/interfaces/ISwapError.ts#L24)

GET or POST status code

#### Overrides

```ts
ISwapErrorData.statusCode
```

***

### subtype

```ts
readonly subtype: SwapErrorType;
```

Defined in: [sdk/sdk-common/src/swap/interfaces/ISwapError.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/swap/interfaces/ISwapError.ts#L20)

Specific error for the swap service

#### Overrides

```ts
ISwapErrorData.subtype
```

***

### type

```ts
readonly type: SwapError;
```

Defined in: [sdk/sdk-common/src/swap/interfaces/ISwapError.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/swap/interfaces/ISwapError.ts#L18)

Error type main category

#### Overrides

[`ISDKError`](ISDKError.md).[`type`](ISDKError.md#type)

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

[`ISDKError`](ISDKError.md).[`toString`](ISDKError.md#tostring)
