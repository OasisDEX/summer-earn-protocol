# Class: ChainInfo

Defined in: [sdk/sdk-common/src/common/implementation/ChainInfo.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ChainInfo.ts#L14)

## Name

ChainInfo

## See

IChainInfo

## Implements

- [`IChainInfo`](../interfaces/IChainInfo.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/ChainInfo.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ChainInfo.ts#L16)

SIGNATURE

#### Implementation of

[`IChainInfo`](../interfaces/IChainInfo.md).[`[___signature__]`](../interfaces/IChainInfo.md#___signature__)

***

### chainId

```ts
readonly chainId: ChainId;
```

Defined in: [sdk/sdk-common/src/common/implementation/ChainInfo.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ChainInfo.ts#L19)

ATTRIBUTES

#### Implementation of

[`IChainInfo`](../interfaces/IChainInfo.md).[`chainId`](../interfaces/IChainInfo.md#chainid)

***

### name

```ts
readonly name: string;
```

Defined in: [sdk/sdk-common/src/common/implementation/ChainInfo.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ChainInfo.ts#L20)

The name of the network

#### Implementation of

[`IChainInfo`](../interfaces/IChainInfo.md).[`name`](../interfaces/IChainInfo.md#name)

## Methods

### equals()

```ts
equals(chainInfo): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/ChainInfo.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ChainInfo.ts#L33)

#### Parameters

##### chainInfo

`ChainInfo`

The chain info to compare

#### Returns

`boolean`

true if the chain infos are equal

Equality is determined by the chain ID

#### Name

equals

#### Description

Checks if two chain infos are equal

#### Implementation of

[`IChainInfo`](../interfaces/IChainInfo.md).[`equals`](../interfaces/IChainInfo.md#equals)

***

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/implementation/ChainInfo.ts:37](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ChainInfo.ts#L37)

#### Returns

`string`

string

The string representation should have enough info to debug the object

#### Name

toString

#### Description

Returns a string representation of the object

#### Implementation of

[`IChainInfo`](../interfaces/IChainInfo.md).[`toString`](../interfaces/IChainInfo.md#tostring)

***

### createFrom()

```ts
static createFrom(params): ChainInfo;
```

Defined in: [sdk/sdk-common/src/common/implementation/ChainInfo.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ChainInfo.ts#L23)

FACTORY METHODS

#### Parameters

##### params

[`ChainInfoParameters`](../type-aliases/ChainInfoParameters.md)

#### Returns

`ChainInfo`
