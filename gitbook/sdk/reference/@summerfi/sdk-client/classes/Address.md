# Class: Address

Defined in: [sdk/sdk-common/src/common/implementation/Address.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Address.ts#L16)

Address

## See

IAddress

## Implements

- [`IAddress`](../interfaces/IAddress.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/Address.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Address.ts#L18)

SIGNATURE

#### Implementation of

[`IAddress`](../interfaces/IAddress.md).[`[___signature__]`](../interfaces/IAddress.md#___signature__)

***

### type

```ts
readonly type: AddressType;
```

Defined in: [sdk/sdk-common/src/common/implementation/Address.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Address.ts#L22)

The type of the address

#### Implementation of

[`IAddress`](../interfaces/IAddress.md).[`type`](../interfaces/IAddress.md#type)

***

### value

```ts
readonly value: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/implementation/Address.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Address.ts#L21)

ATTRIBUTES

#### Implementation of

[`IAddress`](../interfaces/IAddress.md).[`value`](../interfaces/IAddress.md#value)

***

### ZeroAddressEthereum

```ts
static ZeroAddressEthereum: Address;
```

Defined in: [sdk/sdk-common/src/common/implementation/Address.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Address.ts#L25)

CONSTANTS

## Methods

### equals()

```ts
equals(address): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/Address.ts:63](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Address.ts#L63)

PUBLIC METHODS

#### Parameters

##### address

`Address`

#### Returns

`boolean`

#### Implementation of

[`IAddress`](../interfaces/IAddress.md).[`equals`](../interfaces/IAddress.md#equals)

***

### toBigNumber()

```ts
toBigNumber(): BigNumber;
```

Defined in: [sdk/sdk-common/src/common/implementation/Address.ts:73](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Address.ts#L73)

#### Returns

`BigNumber`

#### See

IValueConverter.toBigNumber

***

### toSolidityValue()

```ts
toSolidityValue(): `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/implementation/Address.ts:68](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Address.ts#L68)

#### Returns

`` `0x${string}` ``

#### See

IValueConverter.toBigNumber

#### Implementation of

[`IAddress`](../interfaces/IAddress.md).[`toSolidityValue`](../interfaces/IAddress.md#tosolidityvalue)

***

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/implementation/Address.ts:78](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Address.ts#L78)

#### Returns

`string`

#### See

IPrintable.toString

#### Implementation of

[`IAddress`](../interfaces/IAddress.md).[`toString`](../interfaces/IAddress.md#tostring)

***

### createFrom()

```ts
static createFrom(params): Address;
```

Defined in: [sdk/sdk-common/src/common/implementation/Address.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Address.ts#L32)

FACTORY METHODS

#### Parameters

##### params

[`AddressParameters`](../type-aliases/AddressParameters.md)

#### Returns

`Address`

***

### createFromEthereum()

```ts
static createFromEthereum(params): Address;
```

Defined in: [sdk/sdk-common/src/common/implementation/Address.ts:36](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Address.ts#L36)

#### Parameters

##### params

###### value

`string`

#### Returns

`Address`

***

### getType()

```ts
static getType(address): AddressType;
```

Defined in: [sdk/sdk-common/src/common/implementation/Address.ts:45](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Address.ts#L45)

#### Parameters

##### address

`string`

#### Returns

[`AddressType`](../enumerations/AddressType.md)

***

### isValid()

```ts
static isValid(address): boolean;
```

Defined in: [sdk/sdk-common/src/common/implementation/Address.ts:40](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Address.ts#L40)

#### Parameters

##### address

`string`

#### Returns

`boolean`
