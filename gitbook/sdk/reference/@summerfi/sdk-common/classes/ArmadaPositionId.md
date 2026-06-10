# Class: ArmadaPositionId

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPositionId.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPositionId.ts#L17)

ArmadaPositionId

## See

IArmadaPositionId

## Extends

- [`PositionId`](PositionId.md)

## Implements

- [`IArmadaPositionId`](../interfaces/IArmadaPositionId.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPositionId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPositionId.ts#L19)

SIGNATURE

#### Implementation of

[`IArmadaPositionId`](../interfaces/IArmadaPositionId.md).[`[___signature__]`](../interfaces/IArmadaPositionId.md#___signature__-1)

#### Inherited from

[`PositionId`](PositionId.md).[`[___signature__]`](PositionId.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/PositionId.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PositionId.ts#L16)

SIGNATURE

#### Implementation of

```ts
IArmadaPositionId.[___signature__]
```

#### Inherited from

```ts
PositionId.[___signature__]
```

***

### id

```ts
readonly id: string;
```

Defined in: [sdk/sdk-common/src/common/implementation/PositionId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PositionId.ts#L19)

ATTRIBUTES

#### Implementation of

[`IArmadaPositionId`](../interfaces/IArmadaPositionId.md).[`id`](../interfaces/IArmadaPositionId.md#id)

#### Inherited from

[`PositionId`](PositionId.md).[`id`](PositionId.md#id)

***

### type

```ts
readonly type: Armada = PositionType.Armada;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPositionId.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPositionId.ts#L22)

ATTRIBUTES

#### Implementation of

[`IArmadaPositionId`](../interfaces/IArmadaPositionId.md).[`type`](../interfaces/IArmadaPositionId.md#type)

#### Overrides

[`PositionId`](PositionId.md).[`type`](PositionId.md#type)

***

### user

```ts
readonly user: IUser;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPositionId.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPositionId.ts#L23)

User that opened the position, used to identify the position in a Fleet Commander

#### Implementation of

[`IArmadaPositionId`](../interfaces/IArmadaPositionId.md).[`user`](../interfaces/IArmadaPositionId.md#user)

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/implementation/PositionId.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PositionId.ts#L30)

#### Returns

`string`

#### See

IPrintable.toString

#### Inherited from

[`PositionId`](PositionId.md).[`toString`](PositionId.md#tostring)

***

### createFrom()

```ts
static createFrom(params): ArmadaPositionId;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPositionId.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPositionId.ts#L26)

Factory method

#### Parameters

##### params

[`ArmadaPositionIdParameters`](../type-aliases/ArmadaPositionIdParameters.md)

#### Returns

`ArmadaPositionId`
