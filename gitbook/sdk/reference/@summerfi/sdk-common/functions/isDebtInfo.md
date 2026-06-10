# Function: isDebtInfo()

```ts
function isDebtInfo(maybeDebtInfo): maybeDebtInfo is Readonly<{ debtAvailable: ITokenAmount; debtCeiling: ITokenAmount; dustLimit: ITokenAmount; interestRate: IPercentage; originationFee: IPercentage; price: IPrice; priceUSD: IPrice; token: ITokenStanalone; totalBorrowed: ITokenAmount }>;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts:67](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts#L67)

## Parameters

### maybeDebtInfo

`unknown`

## Returns

`maybeDebtInfo is Readonly<{ debtAvailable: ITokenAmount; debtCeiling: ITokenAmount; dustLimit: ITokenAmount; interestRate: IPercentage; originationFee: IPercentage; price: IPrice; priceUSD: IPrice; token: ITokenStanalone; totalBorrowed: ITokenAmount }>`

true if the object is an IDebtInfo

## Description

Type guard for IDebtInfo
