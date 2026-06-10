# Class: PositionsManager

Defined in: [sdk/sdk-common/src/orders/common/implementation/PositionsManager.ts:10](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/common/implementation/PositionsManager.ts#L10)

PositionsManager

## See

IPositionsManager

## Implements

- [`IPositionsManager`](../interfaces/IPositionsManager.md)
- [`IPrintable`](../interfaces/IPrintable.md)

## Properties

### address

```ts
address: IAddress;
```

Defined in: [sdk/sdk-common/src/orders/common/implementation/PositionsManager.ts:11](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/common/implementation/PositionsManager.ts#L11)

Address of the Positions Manager

#### Implementation of

[`IPositionsManager`](../interfaces/IPositionsManager.md).[`address`](../interfaces/IPositionsManager.md#address)

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/orders/common/implementation/PositionsManager.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/common/implementation/PositionsManager.ts#L23)

Returns a string representation of an object.

#### Returns

`string`

#### Implementation of

[`IPrintable`](../interfaces/IPrintable.md).[`toString`](../interfaces/IPrintable.md#tostring)

***

### createFrom()

```ts
static createFrom(params): PositionsManager;
```

Defined in: [sdk/sdk-common/src/orders/common/implementation/PositionsManager.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/common/implementation/PositionsManager.ts#L14)

Factory method

#### Parameters

##### params

[`IPositionsManagerData`](../type-aliases/IPositionsManagerData.md)

#### Returns

`PositionsManager`
