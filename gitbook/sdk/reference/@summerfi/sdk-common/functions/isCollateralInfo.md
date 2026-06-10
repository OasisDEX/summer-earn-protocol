# Function: isCollateralInfo()

```ts
function isCollateralInfo(maybeCollateralInfo): maybeCollateralInfo is Readonly<{ liquidationPenalty: IPercentage; liquidationThreshold: IRiskRatio; maxSupply: ITokenAmount; price: IPrice; priceUSD: IPrice; token: ITokenStanalone; tokensLocked: ITokenAmount }>;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts:59](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ICollateralInfo.ts#L59)

## Parameters

### maybeCollateralInfo

`unknown`

## Returns

`maybeCollateralInfo is Readonly<{ liquidationPenalty: IPercentage; liquidationThreshold: IRiskRatio; maxSupply: ITokenAmount; price: IPrice; priceUSD: IPrice; token: ITokenStanalone; tokensLocked: ITokenAmount }>`

true if the object is an ICollateralInfo

## Description

Type guard for ICollateralInfo
