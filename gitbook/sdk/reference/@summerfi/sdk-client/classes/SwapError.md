# Class: SwapError

Defined in: [sdk/sdk-common/src/swap/implementation/SwapError.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/swap/implementation/SwapError.ts#L16)

SwapError

## See

ISwapError

## Extends

- [`SDKError`](SDKError.md)

## Implements

- [`ISwapError`](../interfaces/ISwapError.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/swap/implementation/SwapError.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/swap/implementation/SwapError.ts#L18)

SIGNATURE

#### Implementation of

[`ISwapError`](../interfaces/ISwapError.md).[`[___signature__]`](../interfaces/ISwapError.md#___signature__-1)

#### Inherited from

[`SDKError`](SDKError.md).[`[___signature__]`](SDKError.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/SDKError.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/SDKError.ts#L16)

SIGNATURE

#### Implementation of

```ts
ISwapError.[___signature__]
```

#### Inherited from

```ts
SDKError.[___signature__]
```

***

### apiQuery

```ts
readonly apiQuery: string;
```

Defined in: [sdk/sdk-common/src/swap/implementation/SwapError.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/swap/implementation/SwapError.ts#L23)

Full URL of the API query that generated the error

#### Implementation of

[`ISwapError`](../interfaces/ISwapError.md).[`apiQuery`](../interfaces/ISwapError.md#apiquery)

***

### cause?

```ts
optional cause: unknown;
```

Defined in: node\_modules/.pnpm/typescript@5.9.3/node\_modules/typescript/lib/lib.es2022.error.d.ts:26

#### Inherited from

[`SDKError`](SDKError.md).[`cause`](SDKError.md#cause)

***

### message

```ts
readonly message: string;
```

Defined in: [sdk/sdk-common/src/common/implementation/SDKError.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/SDKError.ts#L21)

Free form debug message, used to debug the issue through the console

#### Implementation of

[`ISwapError`](../interfaces/ISwapError.md).[`message`](../interfaces/ISwapError.md#message)

#### Inherited from

[`SDKError`](SDKError.md).[`message`](SDKError.md#message)

***

### name

```ts
name: string;
```

Defined in: node\_modules/.pnpm/typescript@5.9.3/node\_modules/typescript/lib/lib.es5.d.ts:1076

#### Inherited from

[`SDKError`](SDKError.md).[`name`](SDKError.md#name)

***

### reason

```ts
readonly reason: string;
```

Defined in: [sdk/sdk-common/src/common/implementation/SDKError.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/SDKError.ts#L20)

Free form reason message, used to provide a short description of the problem

#### Implementation of

[`ISwapError`](../interfaces/ISwapError.md).[`reason`](../interfaces/ISwapError.md#reason)

#### Inherited from

[`SDKError`](SDKError.md).[`reason`](SDKError.md#reason)

***

### stack?

```ts
optional stack: string;
```

Defined in: node\_modules/.pnpm/typescript@5.9.3/node\_modules/typescript/lib/lib.es5.d.ts:1078

#### Inherited from

[`SDKError`](SDKError.md).[`stack`](SDKError.md#stack)

***

### statusCode

```ts
readonly statusCode: number;
```

Defined in: [sdk/sdk-common/src/swap/implementation/SwapError.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/swap/implementation/SwapError.ts#L24)

GET or POST status code

#### Implementation of

[`ISwapError`](../interfaces/ISwapError.md).[`statusCode`](../interfaces/ISwapError.md#statuscode)

***

### subtype

```ts
readonly subtype: SwapErrorType;
```

Defined in: [sdk/sdk-common/src/swap/implementation/SwapError.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/swap/implementation/SwapError.ts#L22)

Specific error for the swap service

#### Implementation of

[`ISwapError`](../interfaces/ISwapError.md).[`subtype`](../interfaces/ISwapError.md#subtype)

***

### type

```ts
readonly type: SwapError;
```

Defined in: [sdk/sdk-common/src/swap/implementation/SwapError.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/swap/implementation/SwapError.ts#L21)

ATTRIBUTES

#### Implementation of

[`ISwapError`](../interfaces/ISwapError.md).[`type`](../interfaces/ISwapError.md#type)

#### Overrides

[`SDKError`](SDKError.md).[`type`](SDKError.md#type)

***

### stackTraceLimit

```ts
static stackTraceLimit: number;
```

Defined in: node\_modules/.pnpm/@types+node@20.19.37/node\_modules/@types/node/globals.d.ts:68

The `Error.stackTraceLimit` property specifies the number of stack frames
collected by a stack trace (whether generated by `new Error().stack` or
`Error.captureStackTrace(obj)`).

The default value is `10` but may be set to any valid JavaScript number. Changes
will affect any stack trace captured _after_ the value has been changed.

If set to a non-number value, or set to a negative number, stack traces will
not capture any frames.

#### Inherited from

[`SDKError`](SDKError.md).[`stackTraceLimit`](SDKError.md#stacktracelimit)

## Methods

### captureStackTrace()

```ts
static captureStackTrace(targetObject, constructorOpt?): void;
```

Defined in: node\_modules/.pnpm/@types+node@20.19.37/node\_modules/@types/node/globals.d.ts:52

Creates a `.stack` property on `targetObject`, which when accessed returns
a string representing the location in the code at which
`Error.captureStackTrace()` was called.

```js
const myObject = {};
Error.captureStackTrace(myObject);
myObject.stack;  // Similar to `new Error().stack`
```

The first line of the trace will be prefixed with
`${myObject.name}: ${myObject.message}`.

The optional `constructorOpt` argument accepts a function. If given, all frames
above `constructorOpt`, including `constructorOpt`, will be omitted from the
generated stack trace.

The `constructorOpt` argument is useful for hiding implementation
details of error generation from the user. For instance:

```js
function a() {
  b();
}

function b() {
  c();
}

function c() {
  // Create an error without stack trace to avoid calculating the stack trace twice.
  const { stackTraceLimit } = Error;
  Error.stackTraceLimit = 0;
  const error = new Error();
  Error.stackTraceLimit = stackTraceLimit;

  // Capture the stack trace above function b
  Error.captureStackTrace(error, b); // Neither function c, nor b is included in the stack trace
  throw error;
}

a();
```

#### Parameters

##### targetObject

`object`

##### constructorOpt?

`Function`

#### Returns

`void`

#### Inherited from

[`SDKError`](SDKError.md).[`captureStackTrace`](SDKError.md#capturestacktrace)

***

### createFrom()

```ts
static createFrom(params): SwapError;
```

Defined in: [sdk/sdk-common/src/swap/implementation/SwapError.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/swap/implementation/SwapError.ts#L27)

FACTORY

#### Parameters

##### params

[`SwapErrorParams`](../type-aliases/SwapErrorParams.md)

#### Returns

`SwapError`

#### Overrides

[`SDKError`](SDKError.md).[`createFrom`](SDKError.md#createfrom)

***

### prepareStackTrace()

```ts
static prepareStackTrace(err, stackTraces): any;
```

Defined in: node\_modules/.pnpm/@types+node@20.19.37/node\_modules/@types/node/globals.d.ts:56

#### Parameters

##### err

`Error`

##### stackTraces

`CallSite`[]

#### Returns

`any`

#### See

https://v8.dev/docs/stack-trace-api#customizing-stack-traces

#### Inherited from

[`SDKError`](SDKError.md).[`prepareStackTrace`](SDKError.md#preparestacktrace)
