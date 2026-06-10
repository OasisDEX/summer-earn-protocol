# Interface: ISparkLendingPoolId

Defined in: [sdk/protocol-plugins/src/plugins/spark/interfaces/ISparkLendingPoolId.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/spark/interfaces/ISparkLendingPoolId.ts#L18)

ISparkLendingPoolId

## Description

Identifier of a lending pool in the Spark protocol

Typescript forces the interface to re-declare any properties that have different BUT compatible types.
This may be fixed eventually, there is a discussion on the topic here: https://github.com/microsoft/TypeScript/issues/16936

## Extends

- `ISparkLendingPoolIdData`.[`ILendingPoolId`](ILendingPoolId.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/protocol-plugins/src/plugins/spark/interfaces/ISparkLendingPoolId.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/spark/interfaces/ISparkLendingPoolId.ts#L20)

Signature used to differentiate it from similar interfaces

#### Inherited from

[`ILendingPoolId`](ILendingPoolId.md).[`[___signature__]`](ILendingPoolId.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts#L23)

Signature to differentiate it from other interfaces

#### Inherited from

```ts
ILendingPoolId.[___signature__]
```

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPoolId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPoolId.ts#L19)

Signature to differentiate from similar interfaces

#### Inherited from

```ts
ILendingPoolId.[___signature__]
```

***

### collateralToken

```ts
readonly collateralToken: ITokenStanalone;
```

Defined in: [sdk/protocol-plugins/src/plugins/spark/interfaces/ISparkLendingPoolId.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/spark/interfaces/ISparkLendingPoolId.ts#L26)

The token used to collateralize the position

#### Overrides

```ts
ISparkLendingPoolIdData.collateralToken
```

***

### debtToken

```ts
readonly debtToken: ITokenStanalone;
```

Defined in: [sdk/protocol-plugins/src/plugins/spark/interfaces/ISparkLendingPoolId.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/spark/interfaces/ISparkLendingPoolId.ts#L28)

The token used to borrow funds

#### Overrides

```ts
ISparkLendingPoolIdData.debtToken
```

***

### emodeType

```ts
readonly emodeType: EmodeType;
```

Defined in: [sdk/protocol-plugins/src/plugins/spark/interfaces/ISparkLendingPoolId.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/spark/interfaces/ISparkLendingPoolId.ts#L24)

The efficiency mode of the pool

#### Overrides

```ts
ISparkLendingPoolIdData.emodeType
```

***

### protocol

```ts
readonly protocol: ISparkProtocol;
```

Defined in: [sdk/protocol-plugins/src/plugins/spark/interfaces/ISparkLendingPoolId.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/spark/interfaces/ISparkLendingPoolId.ts#L22)

The protocol to which the pool belongs

#### Overrides

[`ILendingPoolId`](ILendingPoolId.md).[`protocol`](ILendingPoolId.md#protocol)

***

### type

```ts
readonly type: Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts:36](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts#L36)

Pool type

#### Inherited from

[`ILendingPoolId`](ILendingPoolId.md).[`type`](ILendingPoolId.md#type)
