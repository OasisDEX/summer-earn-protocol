# Abstract Class: Protocol

Defined in: [sdk/sdk-common/src/common/implementation/Protocol.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Protocol.ts#L16)

Protocol

## See

IProtocol

## Extended by

- [`AaveV3Protocol`](AaveV3Protocol.md)
- [`MakerProtocol`](MakerProtocol.md)
- [`MorphoProtocol`](MorphoProtocol.md)
- [`SparkProtocol`](SparkProtocol.md)
- [`ArmadaProtocol`](ArmadaProtocol.md)

## Implements

- [`IProtocol`](../interfaces/IProtocol.md)
- [`IPrintable`](../interfaces/IPrintable.md)

## Constructors

### Constructor

```ts
protected new Protocol(params): Protocol;
```

Defined in: [sdk/sdk-common/src/common/implementation/Protocol.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Protocol.ts#L25)

SEALED CONSTRUCTOR

#### Parameters

##### params

[`ProtocolParameters`](../type-aliases/ProtocolParameters.md)

#### Returns

`Protocol`

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/Protocol.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Protocol.ts#L18)

SIGNATURE

#### Implementation of

[`IProtocol`](../interfaces/IProtocol.md).[`[___signature__]`](../interfaces/IProtocol.md#___signature__)

***

### chainInfo

```ts
readonly chainInfo: IChainInfo;
```

Defined in: [sdk/sdk-common/src/common/implementation/Protocol.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Protocol.ts#L22)

The chain information

#### Implementation of

[`IProtocol`](../interfaces/IProtocol.md).[`chainInfo`](../interfaces/IProtocol.md#chaininfo)

***

### name

```ts
abstract readonly name: ProtocolName;
```

Defined in: [sdk/sdk-common/src/common/implementation/Protocol.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Protocol.ts#L21)

ATTRIBUTES

#### Implementation of

[`IProtocol`](../interfaces/IProtocol.md).[`name`](../interfaces/IProtocol.md#name)

## Methods

### equals()

```ts
equals(protocol): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/Protocol.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Protocol.ts#L32)

#### Parameters

##### protocol

`Protocol`

#### Returns

`boolean`

#### See

IProtocol.equals

#### Implementation of

[`IProtocol`](../interfaces/IProtocol.md).[`equals`](../interfaces/IProtocol.md#equals)

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

#### Implementation of

[`IPrintable`](../interfaces/IPrintable.md).[`toString`](../interfaces/IPrintable.md#tostring)
