# Type Alias: ISpotPriceInfo

```ts
type ISpotPriceInfo = object;
```

Defined in: [sdk/sdk-common/src/oracle/ISpotPriceInfo.ts:10](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/oracle/ISpotPriceInfo.ts#L10)

## Name

ISpotPriceInfo

## Description

Gives the current market price for a specific asset

## Properties

### price

```ts
price: IPrice;
```

Defined in: [sdk/sdk-common/src/oracle/ISpotPriceInfo.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/oracle/ISpotPriceInfo.ts#L16)

The price of the asset

***

### provider

```ts
provider: OracleProviderType;
```

Defined in: [sdk/sdk-common/src/oracle/ISpotPriceInfo.ts:12](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/oracle/ISpotPriceInfo.ts#L12)

The oracle provider type

***

### token

```ts
token: ITokenStanalone;
```

Defined in: [sdk/sdk-common/src/oracle/ISpotPriceInfo.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/oracle/ISpotPriceInfo.ts#L14)

The token for which the price is being requested. Also included in price, but added here for convenience
