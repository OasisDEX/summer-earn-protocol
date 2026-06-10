# Interface: IMakerLendingPoolId

Defined in: [sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerLendingPoolId.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerLendingPoolId.ts#L17)

## Name

IMakerLendingPoolId

## Description

Represents a lending pool's ID for the Maker protocol

It includes the ILK type which will determine which pool will be used

## Extends

- [`ILendingPoolId`](ILendingPoolId.md).`IMakerLendingPoolIdData`

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerLendingPoolId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerLendingPoolId.ts#L19)

Signature to differentiate from similar interfaces

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

Defined in: [sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerLendingPoolId.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerLendingPoolId.ts#L25)

The token used to collateralize the position

#### Overrides

```ts
IMakerLendingPoolIdData.collateralToken
```

***

### debtToken

```ts
readonly debtToken: ITokenStanalone;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerLendingPoolId.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerLendingPoolId.ts#L27)

The token used to borrow funds

#### Overrides

```ts
IMakerLendingPoolIdData.debtToken
```

***

### ilkType

```ts
readonly ilkType: ILKType;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerLendingPoolId.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerLendingPoolId.ts#L23)

The ILK type of the pool

#### Overrides

```ts
IMakerLendingPoolIdData.ilkType
```

***

### protocol

```ts
readonly protocol: IMakerProtocol;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerLendingPoolId.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerLendingPoolId.ts#L21)

The Maker protocol

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
