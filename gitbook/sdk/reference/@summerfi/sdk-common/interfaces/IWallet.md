# Interface: IWallet

Defined in: [sdk/sdk-common/src/common/interfaces/IWallet.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IWallet.ts#L16)

## Name

IWallet

## Description

Interface for the implementors of the wallet

This is present in the system in case it is needed to add extra information to the
wallet type

## Extends

- [`IWalletData`](../type-aliases/IWalletData.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IWallet.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IWallet.ts#L18)

Signature to differentiate from similar interfaces

***

### address

```ts
readonly address: IAddress;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IWallet.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IWallet.ts#L20)

Address of the wallet, valid for the different chains

#### Overrides

```ts
IWalletData.address
```

## Methods

### equals()

```ts
equals(token): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IWallet.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IWallet.ts#L30)

#### Parameters

##### token

`IWallet`

#### Returns

`boolean`

true if the wallets are equal

Equality is determined by the address

#### Name

equals

#### Description

Checks if two wallets are equal
