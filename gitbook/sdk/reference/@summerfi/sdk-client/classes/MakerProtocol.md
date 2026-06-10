# Class: MakerProtocol

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerProtocol.ts:13](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerProtocol.ts#L13)

MakerProtocol

## See

IMakerProtocolData

## Extends

- [`Protocol`](Protocol.md)

## Implements

- [`IMakerProtocol`](../interfaces/IMakerProtocol.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerProtocol.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerProtocol.ts#L15)

SIGNATURE

#### Implementation of

[`IMakerProtocol`](../interfaces/IMakerProtocol.md).[`[___signature__]`](../interfaces/IMakerProtocol.md#___signature__-1)

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
IMakerProtocol.[___signature__]
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

[`IMakerProtocol`](../interfaces/IMakerProtocol.md).[`chainInfo`](../interfaces/IMakerProtocol.md#chaininfo)

#### Inherited from

[`Protocol`](Protocol.md).[`chainInfo`](Protocol.md#chaininfo)

***

### name

```ts
readonly name: Maker = ProtocolName.Maker;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerProtocol.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerProtocol.ts#L18)

ATTRIBUTES

#### Implementation of

[`IMakerProtocol`](../interfaces/IMakerProtocol.md).[`name`](../interfaces/IMakerProtocol.md#name)

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

[`IMakerProtocol`](../interfaces/IMakerProtocol.md).[`equals`](../interfaces/IMakerProtocol.md#equals)

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
static createFrom(params): MakerProtocol;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerProtocol.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerProtocol.ts#L21)

FACTORY

#### Parameters

##### params

`MakerProtocolParameters`

#### Returns

`MakerProtocol`
