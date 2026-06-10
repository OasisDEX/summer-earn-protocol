# Class: MakerLendingPoolId

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPoolId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPoolId.ts#L19)

MakerLendingPoolId

## See

IMakerLendingPoolIdData

## Extends

- [`LendingPoolId`](LendingPoolId.md)

## Implements

- [`IMakerLendingPoolId`](../interfaces/IMakerLendingPoolId.md)
- [`IPrintable`](../interfaces/IPrintable.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPoolId.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPoolId.ts#L21)

SIGNATURE

#### Implementation of

[`IMakerLendingPoolId`](../interfaces/IMakerLendingPoolId.md).[`[___signature__]`](../interfaces/IMakerLendingPoolId.md#___signature__-2)

#### Inherited from

[`LendingPoolId`](LendingPoolId.md).[`[___signature__]`](LendingPoolId.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts#L18)

SIGNATURE

#### Implementation of

```ts
IMakerLendingPoolId.[___signature__]
```

#### Inherited from

```ts
LendingPoolId.[___signature__]
```

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/PoolId.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PoolId.ts#L18)

SIGNATURE

#### Implementation of

```ts
IMakerLendingPoolId.[___signature__]
```

#### Inherited from

```ts
LendingPoolId.[___signature__]
```

***

### collateralToken

```ts
readonly collateralToken: ITokenStanalone;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPoolId.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPoolId.ts#L26)

The token used to collateralize the position

#### Implementation of

[`IMakerLendingPoolId`](../interfaces/IMakerLendingPoolId.md).[`collateralToken`](../interfaces/IMakerLendingPoolId.md#collateraltoken)

***

### debtToken

```ts
readonly debtToken: ITokenStanalone;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPoolId.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPoolId.ts#L27)

The token used to borrow funds

#### Implementation of

[`IMakerLendingPoolId`](../interfaces/IMakerLendingPoolId.md).[`debtToken`](../interfaces/IMakerLendingPoolId.md#debttoken)

***

### ilkType

```ts
readonly ilkType: ILKType;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPoolId.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPoolId.ts#L25)

The ILK type of the pool

#### Implementation of

[`IMakerLendingPoolId`](../interfaces/IMakerLendingPoolId.md).[`ilkType`](../interfaces/IMakerLendingPoolId.md#ilktype)

***

### protocol

```ts
readonly protocol: MakerProtocol;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPoolId.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPoolId.ts#L24)

ATTRIBUTES

#### Implementation of

[`IMakerLendingPoolId`](../interfaces/IMakerLendingPoolId.md).[`protocol`](../interfaces/IMakerLendingPoolId.md#protocol)

#### Overrides

[`LendingPoolId`](LendingPoolId.md).[`protocol`](LendingPoolId.md#protocol)

***

### type

```ts
readonly type: Lending = PoolType.Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts#L21)

ATTRIBUTES

#### Implementation of

[`IMakerLendingPoolId`](../interfaces/IMakerLendingPoolId.md).[`type`](../interfaces/IMakerLendingPoolId.md#type)

#### Inherited from

[`LendingPoolId`](LendingPoolId.md).[`type`](LendingPoolId.md#type)

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPoolId.ts:47](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPoolId.ts#L47)

#### Returns

`string`

#### See

IPrintable.toString

#### Implementation of

[`IPrintable`](../interfaces/IPrintable.md).[`toString`](../interfaces/IPrintable.md#tostring)

#### Overrides

[`LendingPoolId`](LendingPoolId.md).[`toString`](LendingPoolId.md#tostring)

***

### createFrom()

```ts
static createFrom(params): MakerLendingPoolId;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPoolId.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPoolId.ts#L30)

FACTORY

#### Parameters

##### params

`MakerLendingPoolIdParameters`

#### Returns

`MakerLendingPoolId`
