# Class: Token

Defined in: [sdk/sdk-common/src/common/implementation/Token.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Token.ts#L17)

## Name

Token

## See

IToken

## Implements

- [`ITokenStanalone`](../interfaces/ITokenStanalone.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/Token.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Token.ts#L19)

SIGNATURE

#### Implementation of

[`ITokenStanalone`](../interfaces/ITokenStanalone.md).[`[___signature__]`](../interfaces/ITokenStanalone.md#___signature__)

***

### address

```ts
readonly address: IAddress;
```

Defined in: [sdk/sdk-common/src/common/implementation/Token.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Token.ts#L25)

Token address

#### Implementation of

[`ITokenStanalone`](../interfaces/ITokenStanalone.md).[`address`](../interfaces/ITokenStanalone.md#address)

***

### chainInfo

```ts
readonly chainInfo: IChainInfo;
```

Defined in: [sdk/sdk-common/src/common/implementation/Token.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Token.ts#L24)

Chain where the token is deployed

#### Implementation of

[`ITokenStanalone`](../interfaces/ITokenStanalone.md).[`chainInfo`](../interfaces/ITokenStanalone.md#chaininfo)

***

### decimals

```ts
readonly decimals: number;
```

Defined in: [sdk/sdk-common/src/common/implementation/Token.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Token.ts#L26)

Number of decimals for the token

#### Implementation of

[`ITokenStanalone`](../interfaces/ITokenStanalone.md).[`decimals`](../interfaces/ITokenStanalone.md#decimals)

***

### name

```ts
readonly name: string;
```

Defined in: [sdk/sdk-common/src/common/implementation/Token.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Token.ts#L23)

Full token name

#### Implementation of

[`ITokenStanalone`](../interfaces/ITokenStanalone.md).[`name`](../interfaces/ITokenStanalone.md#name)

***

### symbol

```ts
readonly symbol: string;
```

Defined in: [sdk/sdk-common/src/common/implementation/Token.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Token.ts#L22)

ATTRIBUTES

#### Implementation of

[`ITokenStanalone`](../interfaces/ITokenStanalone.md).[`symbol`](../interfaces/ITokenStanalone.md#symbol)

## Methods

### equals()

```ts
equals(token): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/Token.ts:45](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Token.ts#L45)

#### Parameters

##### token

`Token`

#### Returns

`boolean`

#### See

IToken.equals

#### Implementation of

[`ITokenStanalone`](../interfaces/ITokenStanalone.md).[`equals`](../interfaces/ITokenStanalone.md#equals)

***

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/implementation/Token.ts:50](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Token.ts#L50)

#### Returns

`string`

#### See

IPrintable.toString

#### Implementation of

[`ITokenStanalone`](../interfaces/ITokenStanalone.md).[`toString`](../interfaces/ITokenStanalone.md#tostring)

***

### createFrom()

```ts
static createFrom(params): Token;
```

Defined in: [sdk/sdk-common/src/common/implementation/Token.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Token.ts#L29)

FACTORY

#### Parameters

##### params

[`TokenParameters`](../type-aliases/TokenParameters.md)

#### Returns

`Token`
