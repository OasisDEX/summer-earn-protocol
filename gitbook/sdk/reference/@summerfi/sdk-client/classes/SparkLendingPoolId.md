# Class: SparkLendingPoolId

Defined in: [sdk/protocol-plugins/src/plugins/spark/implementation/SparkLendingPoolId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/spark/implementation/SparkLendingPoolId.ts#L19)

SparkLendingPoolId

## See

ISparkLendingPoolIdData

## Extends

- [`LendingPoolId`](LendingPoolId.md)

## Implements

- [`ISparkLendingPoolId`](../interfaces/ISparkLendingPoolId.md)
- [`IPrintable`](../interfaces/IPrintable.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/protocol-plugins/src/plugins/spark/implementation/SparkLendingPoolId.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/spark/implementation/SparkLendingPoolId.ts#L21)

SIGNATURE

#### Implementation of

[`ISparkLendingPoolId`](../interfaces/ISparkLendingPoolId.md).[`[___signature__]`](../interfaces/ISparkLendingPoolId.md#___signature__-2)

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
ISparkLendingPoolId.[___signature__]
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
ISparkLendingPoolId.[___signature__]
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

Defined in: [sdk/protocol-plugins/src/plugins/spark/implementation/SparkLendingPoolId.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/spark/implementation/SparkLendingPoolId.ts#L26)

The token used to collateralize the position

#### Implementation of

[`ISparkLendingPoolId`](../interfaces/ISparkLendingPoolId.md).[`collateralToken`](../interfaces/ISparkLendingPoolId.md#collateraltoken)

***

### debtToken

```ts
readonly debtToken: ITokenStanalone;
```

Defined in: [sdk/protocol-plugins/src/plugins/spark/implementation/SparkLendingPoolId.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/spark/implementation/SparkLendingPoolId.ts#L27)

The token used to borrow funds

#### Implementation of

[`ISparkLendingPoolId`](../interfaces/ISparkLendingPoolId.md).[`debtToken`](../interfaces/ISparkLendingPoolId.md#debttoken)

***

### emodeType

```ts
readonly emodeType: EmodeType;
```

Defined in: [sdk/protocol-plugins/src/plugins/spark/implementation/SparkLendingPoolId.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/spark/implementation/SparkLendingPoolId.ts#L25)

The efficiency mode of the pool

#### Implementation of

[`ISparkLendingPoolId`](../interfaces/ISparkLendingPoolId.md).[`emodeType`](../interfaces/ISparkLendingPoolId.md#emodetype)

***

### protocol

```ts
readonly protocol: ISparkProtocol;
```

Defined in: [sdk/protocol-plugins/src/plugins/spark/implementation/SparkLendingPoolId.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/spark/implementation/SparkLendingPoolId.ts#L24)

ATTRIBUTES

#### Implementation of

[`ISparkLendingPoolId`](../interfaces/ISparkLendingPoolId.md).[`protocol`](../interfaces/ISparkLendingPoolId.md#protocol)

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

[`ISparkLendingPoolId`](../interfaces/ISparkLendingPoolId.md).[`type`](../interfaces/ISparkLendingPoolId.md#type)

#### Inherited from

[`LendingPoolId`](LendingPoolId.md).[`type`](LendingPoolId.md#type)

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/protocol-plugins/src/plugins/spark/implementation/SparkLendingPoolId.ts:44](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/spark/implementation/SparkLendingPoolId.ts#L44)

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
static createFrom(params): SparkLendingPoolId;
```

Defined in: [sdk/protocol-plugins/src/plugins/spark/implementation/SparkLendingPoolId.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/spark/implementation/SparkLendingPoolId.ts#L30)

FACTORY

#### Parameters

##### params

`SparkLendingPoolIdParameters`

#### Returns

`SparkLendingPoolId`
