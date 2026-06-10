# Class: User

Defined in: [sdk/sdk-common/src/user/implementation/User.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/user/implementation/User.ts#L19)

## Name

User

## See

IUser

## Implements

- [`IUser`](../interfaces/IUser.md)

## Constructors

### Constructor

```ts
protected new User(params): User;
```

Defined in: [sdk/sdk-common/src/user/implementation/User.ts:42](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/user/implementation/User.ts#L42)

SEALED CONSTRUCTOR

#### Parameters

##### params

[`UserParameters`](../type-aliases/UserParameters.md)

#### Returns

`User`

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/user/implementation/User.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/user/implementation/User.ts#L21)

SIGNATURE

#### Implementation of

[`IUser`](../interfaces/IUser.md).[`[___signature__]`](../interfaces/IUser.md#___signature__)

***

### chainInfo

```ts
readonly chainInfo: IChainInfo;
```

Defined in: [sdk/sdk-common/src/user/implementation/User.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/user/implementation/User.ts#L25)

The chain the user is connected to

#### Implementation of

[`IUser`](../interfaces/IUser.md).[`chainInfo`](../interfaces/IUser.md#chaininfo)

***

### wallet

```ts
readonly wallet: IWallet;
```

Defined in: [sdk/sdk-common/src/user/implementation/User.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/user/implementation/User.ts#L24)

ATTRIBUTES

#### Implementation of

[`IUser`](../interfaces/IUser.md).[`wallet`](../interfaces/IUser.md#wallet)

## Methods

### equals()

```ts
equals(token): boolean;
```

Defined in: [sdk/sdk-common/src/user/implementation/User.ts:50](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/user/implementation/User.ts#L50)

#### Parameters

##### token

[`IUser`](../interfaces/IUser.md)

#### Returns

`boolean`

#### See

IUser.equals

***

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/user/implementation/User.ts:55](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/user/implementation/User.ts#L55)

#### Returns

`string`

#### See

IPrintable.toString

#### Implementation of

[`IUser`](../interfaces/IUser.md).[`toString`](../interfaces/IUser.md#tostring)

***

### createFrom()

```ts
static createFrom(params): User;
```

Defined in: [sdk/sdk-common/src/user/implementation/User.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/user/implementation/User.ts#L28)

FACTORY

#### Parameters

##### params

[`UserParameters`](../type-aliases/UserParameters.md)

#### Returns

`User`

***

### createFromEthereum()

```ts
static createFromEthereum(chainId, addressValue): User;
```

Defined in: [sdk/sdk-common/src/user/implementation/User.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/user/implementation/User.ts#L32)

#### Parameters

##### chainId

`number`

##### addressValue

`` `0x${string}` ``

#### Returns

`User`
