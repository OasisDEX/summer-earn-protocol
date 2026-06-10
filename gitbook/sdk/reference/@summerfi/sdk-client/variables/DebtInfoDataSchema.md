# Variable: DebtInfoDataSchema

```ts
const DebtInfoDataSchema: ZodObject<{
  debtAvailable: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  debtCeiling: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  dustLimit: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  interestRate: ZodType<IPercentage, ZodTypeDef, IPercentage>;
  originationFee: ZodType<IPercentage, ZodTypeDef, IPercentage>;
  price: ZodType<IPrice, ZodTypeDef, IPrice>;
  priceUSD: ZodType<IPrice, ZodTypeDef, IPrice>;
  token: ZodType<ITokenStanalone, ZodTypeDef, ITokenStanalone>;
  totalBorrowed: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
}, "strip", ZodTypeAny, {
  debtAvailable: ITokenAmount;
  debtCeiling: ITokenAmount;
  dustLimit: ITokenAmount;
  interestRate: IPercentage;
  originationFee: IPercentage;
  price: IPrice;
  priceUSD: IPrice;
  token: ITokenStanalone;
  totalBorrowed: ITokenAmount;
}, {
  debtAvailable: ITokenAmount;
  debtCeiling: ITokenAmount;
  dustLimit: ITokenAmount;
  interestRate: IPercentage;
  originationFee: IPercentage;
  price: IPrice;
  priceUSD: IPrice;
  token: ITokenStanalone;
  totalBorrowed: ITokenAmount;
}>;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts:45](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/IDebtInfo.ts#L45)

## Description

Zod schema for IDebtInfo
