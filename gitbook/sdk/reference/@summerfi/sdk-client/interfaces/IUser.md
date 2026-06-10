# Interface: IUser

Defined in: [sdk/sdk-common/src/user/interfaces/IUser.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/user/interfaces/IUser.ts#L14)

Represents a user of the system connected with a wallet on a particular chain

## Extends

- [`IUserData`](../type-aliases/IUserData.md).[`IPrintable`](IPrintable.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/user/interfaces/IUser.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/user/interfaces/IUser.ts#L16)

Signature to differentiate from similar interfaces

***

### chainInfo

```ts
readonly chainInfo: IChainInfo;
```

Defined in: [sdk/sdk-common/src/user/interfaces/IUser.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/user/interfaces/IUser.ts#L20)

The chain the user is connected to

#### Overrides

```ts
IUserData.chainInfo
```

***

### wallet

```ts
readonly wallet: IWallet;
```

Defined in: [sdk/sdk-common/src/user/interfaces/IUser.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/user/interfaces/IUser.ts#L18)

The wallet of the user

#### Overrides

```ts
IUserData.wallet
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
