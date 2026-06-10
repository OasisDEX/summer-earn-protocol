# Interface: IPrintable

Defined in: [sdk/sdk-common/src/common/interfaces/IPrintable.ts:7](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrintable.ts#L7)

## Name

IPrintable

## Description

Interface for printable objects.

This enables more readable debug objects

## Extended by

- [`ITokenStanalone`](ITokenStanalone.md)
- [`IAddress`](IAddress.md)
- [`IChainInfo`](IChainInfo.md)
- [`IFiatCurrencyAmount`](IFiatCurrencyAmount.md)
- [`IPercentage`](IPercentage.md)
- [`IPool`](IPool.md)
- [`IPrice`](IPrice.md)
- [`IRiskRatio`](IRiskRatio.md)
- [`ISDKError`](ISDKError.md)
- [`ITokenAmount`](ITokenAmount.md)
- [`IExternalLendingPosition`](IExternalLendingPosition.md)
- [`IExternalLendingPositionId`](IExternalLendingPositionId.md)
- [`IUser`](IUser.md)

## Methods

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
