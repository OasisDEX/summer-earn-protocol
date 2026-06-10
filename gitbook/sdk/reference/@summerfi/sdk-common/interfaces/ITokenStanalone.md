# Interface: ITokenStanalone

Defined in: [sdk/sdk-common/src/common/interfaces/IToken.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IToken.ts#L15)

## Name

IToken

## Description

Represents an token in a Chain, typically used to represent ERC-20 tokens

## Extends

- [`ITokenData`](../type-aliases/ITokenData.md).[`IPrintable`](IPrintable.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IToken.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IToken.ts#L17)

Signature to differentiate from similar interfaces

***

### address

```ts
readonly address: IAddress;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IToken.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IToken.ts#L21)

Token address

#### Overrides

```ts
ITokenData.address
```

***

### chainInfo

```ts
readonly chainInfo: IChainInfo;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IToken.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IToken.ts#L19)

Chain where the token is deployed

#### Overrides

```ts
ITokenData.chainInfo
```

***

### decimals

```ts
readonly decimals: number;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IToken.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IToken.ts#L27)

Number of decimals for the token

#### Overrides

```ts
ITokenData.decimals
```

***

### name

```ts
readonly name: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IToken.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IToken.ts#L25)

Full token name

#### Overrides

```ts
ITokenData.name
```

***

### symbol

```ts
readonly symbol: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IToken.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IToken.ts#L23)

Token symbol, usually a short representation of name and used in tickers

#### Overrides

```ts
ITokenData.symbol
```

## Methods

### equals()

```ts
equals(token): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IToken.ts:37](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IToken.ts#L37)

#### Parameters

##### token

`IToken`

The token to compare

#### Returns

`boolean`

true if the tokens are equal

Equality is determined by the address and chain information

#### Name

equals

#### Description

Checks if two tokens are equal

***

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
