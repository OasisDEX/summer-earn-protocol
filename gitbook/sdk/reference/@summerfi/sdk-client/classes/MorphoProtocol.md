# Class: MorphoProtocol

Defined in: [sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoProtocol.ts:13](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoProtocol.ts#L13)

MorphoProtocol

## See

IMorphoProtocol

## Extends

- [`Protocol`](Protocol.md)

## Implements

- [`IMorphoProtocol`](../interfaces/IMorphoProtocol.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoProtocol.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoProtocol.ts#L15)

SIGNATURE

#### Implementation of

[`IMorphoProtocol`](../interfaces/IMorphoProtocol.md).[`[___signature__]`](../interfaces/IMorphoProtocol.md#___signature__-1)

#### Inherited from

[`Protocol`](Protocol.md).[`[___signature__]`](Protocol.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/Protocol.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Protocol.ts#L18)

SIGNATURE

#### Implementation of

```ts
IMorphoProtocol.[___signature__]
```

#### Inherited from

```ts
Protocol.[___signature__]
```

***

### chainInfo

```ts
readonly chainInfo: IChainInfo;
```

Defined in: [sdk/sdk-common/src/common/implementation/Protocol.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Protocol.ts#L22)

The chain information

#### Implementation of

[`IMorphoProtocol`](../interfaces/IMorphoProtocol.md).[`chainInfo`](../interfaces/IMorphoProtocol.md#chaininfo)

#### Inherited from

[`Protocol`](Protocol.md).[`chainInfo`](Protocol.md#chaininfo)

***

### name

```ts
readonly name: MorphoBlue = ProtocolName.MorphoBlue;
```

Defined in: [sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoProtocol.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoProtocol.ts#L18)

ATTRIBUTES

#### Implementation of

[`IMorphoProtocol`](../interfaces/IMorphoProtocol.md).[`name`](../interfaces/IMorphoProtocol.md#name)

#### Overrides

[`Protocol`](Protocol.md).[`name`](Protocol.md#name)

## Methods

### equals()

```ts
equals(protocol): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/Protocol.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Protocol.ts#L32)

#### Parameters

##### protocol

[`Protocol`](Protocol.md)

#### Returns

`boolean`

#### See

IProtocol.equals

#### Implementation of

[`IMorphoProtocol`](../interfaces/IMorphoProtocol.md).[`equals`](../interfaces/IMorphoProtocol.md#equals)

#### Inherited from

[`Protocol`](Protocol.md).[`equals`](Protocol.md#equals)

***

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/implementation/Protocol.ts:37](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Protocol.ts#L37)

#### Returns

`string`

#### See

IPrintable.toString

#### Inherited from

[`Protocol`](Protocol.md).[`toString`](Protocol.md#tostring)

***

### createFrom()

```ts
static createFrom(params): MorphoProtocol;
```

Defined in: [sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoProtocol.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoProtocol.ts#L21)

FACTORY

#### Parameters

##### params

`MorphoProtocolParameters`

#### Returns

`MorphoProtocol`
