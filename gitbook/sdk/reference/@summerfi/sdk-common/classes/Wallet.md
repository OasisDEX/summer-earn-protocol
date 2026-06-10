# Class: Wallet

Defined in: [sdk/sdk-common/src/common/implementation/Wallet.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Wallet.ts#L14)

**`Interface`**

Wallet

## See

IWalletData

## Implements

- [`IWallet`](../interfaces/IWallet.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/Wallet.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Wallet.ts#L16)

SIGNATURE

#### Implementation of

[`IWallet`](../interfaces/IWallet.md).[`[___signature__]`](../interfaces/IWallet.md#___signature__)

***

### address

```ts
readonly address: IAddress;
```

Defined in: [sdk/sdk-common/src/common/implementation/Wallet.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Wallet.ts#L19)

ATTRIBUTES

#### Implementation of

[`IWallet`](../interfaces/IWallet.md).[`address`](../interfaces/IWallet.md#address)

## Methods

### equals()

```ts
equals(wallet): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/Wallet.ts:34](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Wallet.ts#L34)

#### Parameters

##### wallet

`Wallet`

#### Returns

`boolean`

#### See

IWallet.equals

#### Implementation of

[`IWallet`](../interfaces/IWallet.md).[`equals`](../interfaces/IWallet.md#equals)

***

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/implementation/Wallet.ts:39](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Wallet.ts#L39)

#### Returns

`string`

#### See

IPrintable.toString

***

### createFrom()

```ts
static createFrom(params): Wallet;
```

Defined in: [sdk/sdk-common/src/common/implementation/Wallet.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Wallet.ts#L22)

FACTORY

#### Parameters

##### params

[`WalletParameters`](../type-aliases/WalletParameters.md)

#### Returns

`Wallet`
