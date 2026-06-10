# Interface: IAddress

Defined in: [sdk/sdk-common/src/common/interfaces/IAddress.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IAddress.ts#L19)

## Name

IAddress

## Description

Represents an address with a certain format, specified by the type

Currently only Ethereum type is supported

## Extends

- [`IAddressData`](../type-aliases/IAddressData.md).[`IPrintable`](IPrintable.md).`ISolidityValue`\<[`AddressValue`](../type-aliases/AddressValue.md)\>

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IAddress.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IAddress.ts#L21)

Signature to differentiate from similar interfaces

***

### type

```ts
readonly type: AddressType;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IAddress.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IAddress.ts#L25)

The type of the address

#### Overrides

```ts
IAddressData.type
```

***

### value

```ts
readonly value: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IAddress.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IAddress.ts#L23)

The address value in the format specified by type

#### Overrides

```ts
IAddressData.value
```

## Methods

### equals()

```ts
equals(address): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IAddress.ts:35](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IAddress.ts#L35)

#### Parameters

##### address

`IAddress`

The address to compare

#### Returns

`boolean`

true if the addresses are equal

Equality is determined by the address value and type

#### Name

equals

#### Description

Checks if two addresses are equal

***

### toSolidityValue()

```ts
toSolidityValue(): `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ISolidityValue.ts:9](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ISolidityValue.ts#L9)

Converts the instance into a Solidity value

#### Returns

`` `0x${string}` ``

#### Inherited from

```ts
ISolidityValue.toSolidityValue
```

***

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrintable.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrintable.ts#L15)

#### Returns

`string`

string

The string representation should have enough info to debug the object

#### Name

toString

#### Description

Returns a string representation of the object

#### Inherited from

[`IPrintable`](IPrintable.md).[`toString`](IPrintable.md#tostring)
