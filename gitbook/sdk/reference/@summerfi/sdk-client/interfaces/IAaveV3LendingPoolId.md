# Interface: IAaveV3LendingPoolId

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/interfaces/IAaveV3LendingPoolId.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/interfaces/IAaveV3LendingPoolId.ts#L18)

IAaveV3LendingPoolId

## Description

Identifier of a lending pool on the Aave v3 protocol

Typescript forces the interface to re-declare any properties that have different BUT compatible types.
This may be fixed eventually, there is a discussion on the topic here: https://github.com/microsoft/TypeScript/issues/16936

## Extends

- [`ILendingPoolId`](ILendingPoolId.md).`IAaveV3LendingPoolIdData`

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/interfaces/IAaveV3LendingPoolId.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/interfaces/IAaveV3LendingPoolId.ts#L20)

Interface signature used to differentiate it from similar interfaces

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

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/interfaces/IAaveV3LendingPoolId.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/interfaces/IAaveV3LendingPoolId.ts#L26)

The token used to collateralized the position

#### Overrides

```ts
IAaveV3LendingPoolIdData.collateralToken
```

***

### debtToken

```ts
readonly debtToken: ITokenStanalone;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/interfaces/IAaveV3LendingPoolId.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/interfaces/IAaveV3LendingPoolId.ts#L28)

The token used to borrow funds

#### Overrides

```ts
IAaveV3LendingPoolIdData.debtToken
```

***

### emodeType

```ts
readonly emodeType: EmodeType;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/interfaces/IAaveV3LendingPoolId.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/interfaces/IAaveV3LendingPoolId.ts#L24)

The pool's efficiency mode

#### Overrides

```ts
IAaveV3LendingPoolIdData.emodeType
```

***

### protocol

```ts
readonly protocol: IAaveV3Protocol;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/interfaces/IAaveV3LendingPoolId.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/interfaces/IAaveV3LendingPoolId.ts#L22)

Aave v3 protocol

#### Overrides

[`ILendingPoolId`](ILendingPoolId.md).[`protocol`](ILendingPoolId.md#protocol)

***

### type

```ts
readonly type: Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts#L28)

Pool type

#### Inherited from

[`ILendingPoolId`](ILendingPoolId.md).[`type`](ILendingPoolId.md#type)
