# Interface: IChainInfo

Defined in: [sdk/sdk-common/src/common/interfaces/IChainInfo.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IChainInfo.ts#L14)

## Name

IChainInfo

## Description

Information used to identify a blockchain network

## Extends

- [`IChainInfoData`](../type-aliases/IChainInfoData.md).[`IPrintable`](IPrintable.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IChainInfo.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IChainInfo.ts#L16)

Signature to differentiate from similar interfaces

***

### chainId

```ts
readonly chainId: ChainId;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IChainInfo.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IChainInfo.ts#L18)

The chain ID of the network

#### Overrides

```ts
IChainInfoData.chainId
```

***

### name

```ts
readonly name: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IChainInfo.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IChainInfo.ts#L20)

The name of the network

#### Overrides

```ts
IChainInfoData.name
```

## Methods

### equals()

```ts
equals(chainInfo): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IChainInfo.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IChainInfo.ts#L30)

#### Parameters

##### chainInfo

[`IChainInfoData`](../type-aliases/IChainInfoData.md)

The chain info to compare

#### Returns

`boolean`

true if the chain infos are equal

Equality is determined by the chain ID

#### Name

equals

#### Description

Checks if two chain infos are equal

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
