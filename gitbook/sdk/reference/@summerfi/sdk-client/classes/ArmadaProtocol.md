# Class: ArmadaProtocol

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaProtocol.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaProtocol.ts#L16)

ArmadaProtocol

## See

IArmadaProtocol

## Extends

- [`Protocol`](Protocol.md)

## Implements

- [`IArmadaProtocol`](../interfaces/IArmadaProtocol.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaProtocol.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaProtocol.ts#L18)

SIGNATURE

#### Implementation of

[`IArmadaProtocol`](../interfaces/IArmadaProtocol.md).[`[___signature__]`](../interfaces/IArmadaProtocol.md#___signature__-1)

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
IArmadaProtocol.[___signature__]
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

[`IArmadaProtocol`](../interfaces/IArmadaProtocol.md).[`chainInfo`](../interfaces/IArmadaProtocol.md#chaininfo)

#### Inherited from

[`Protocol`](Protocol.md).[`chainInfo`](Protocol.md#chaininfo)

***

### name

```ts
readonly name: Armada = ProtocolName.Armada;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaProtocol.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaProtocol.ts#L21)

ATTRIBUTES

#### Implementation of

[`IArmadaProtocol`](../interfaces/IArmadaProtocol.md).[`name`](../interfaces/IArmadaProtocol.md#name)

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

[`IArmadaProtocol`](../interfaces/IArmadaProtocol.md).[`equals`](../interfaces/IArmadaProtocol.md#equals)

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
static createFrom(params): ArmadaProtocol;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaProtocol.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaProtocol.ts#L24)

FACTORY

#### Parameters

##### params

[`ArmadaProtocolParameters`](../type-aliases/ArmadaProtocolParameters.md)

#### Returns

`ArmadaProtocol`
