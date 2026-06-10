# Variable: ArmadaPositionDataSchema

```ts
const ArmadaPositionDataSchema: ZodObject<{
  amount: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  assetPriceUSD: ZodType<IFiatCurrencyAmount, ZodTypeDef, IFiatCurrencyAmount>;
  assets: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  assetsUSD: ZodType<IFiatCurrencyAmount, ZodTypeDef, IFiatCurrencyAmount>;
  claimableSummerToken: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  claimedSummerToken: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  deposits: ZodArray<ZodObject<{
     amount: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
     timestamp: ZodNumber;
   }, "strip", ZodTypeAny, {
     amount: ITokenAmount;
     timestamp: number;
   }, {
     amount: ITokenAmount;
     timestamp: number;
  }>, "many">;
  depositsAmount: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  depositsAmountUSD: ZodType<IFiatCurrencyAmount, ZodTypeDef, IFiatCurrencyAmount>;
  earnings: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  earningsUSD: ZodType<IFiatCurrencyAmount, ZodTypeDef, IFiatCurrencyAmount>;
  id: ZodType<IArmadaPositionId, ZodTypeDef, IArmadaPositionId>;
  netDeposits: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  netDepositsUSD: ZodType<IFiatCurrencyAmount, ZodTypeDef, IFiatCurrencyAmount>;
  pool: ZodType<IArmadaVault, ZodTypeDef, IArmadaVault>;
  rewards: ZodArray<ZodObject<{
     claimable: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
     claimed: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
   }, "strip", ZodTypeAny, {
     claimable: ITokenAmount;
     claimed: ITokenAmount;
   }, {
     claimable: ITokenAmount;
     claimed: ITokenAmount;
  }>, "many">;
  shares: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  type: ZodLiteral<Armada>;
  withdrawals: ZodArray<ZodObject<{
     amount: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
     timestamp: ZodNumber;
   }, "strip", ZodTypeAny, {
     amount: ITokenAmount;
     timestamp: number;
   }, {
     amount: ITokenAmount;
     timestamp: number;
  }>, "many">;
  withdrawalsAmount: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  withdrawalsAmountUSD: ZodType<IFiatCurrencyAmount, ZodTypeDef, IFiatCurrencyAmount>;
}, "strip", ZodTypeAny, {
  amount: ITokenAmount;
  assetPriceUSD: IFiatCurrencyAmount;
  assets: ITokenAmount;
  assetsUSD: IFiatCurrencyAmount;
  claimableSummerToken: ITokenAmount;
  claimedSummerToken: ITokenAmount;
  deposits: object[];
  depositsAmount: ITokenAmount;
  depositsAmountUSD: IFiatCurrencyAmount;
  earnings: ITokenAmount;
  earningsUSD: IFiatCurrencyAmount;
  id: IArmadaPositionId;
  netDeposits: ITokenAmount;
  netDepositsUSD: IFiatCurrencyAmount;
  pool: IArmadaVault;
  rewards: object[];
  shares: ITokenAmount;
  type: Armada;
  withdrawals: object[];
  withdrawalsAmount: ITokenAmount;
  withdrawalsAmountUSD: IFiatCurrencyAmount;
}, {
  amount: ITokenAmount;
  assetPriceUSD: IFiatCurrencyAmount;
  assets: ITokenAmount;
  assetsUSD: IFiatCurrencyAmount;
  claimableSummerToken: ITokenAmount;
  claimedSummerToken: ITokenAmount;
  deposits: object[];
  depositsAmount: ITokenAmount;
  depositsAmountUSD: IFiatCurrencyAmount;
  earnings: ITokenAmount;
  earningsUSD: IFiatCurrencyAmount;
  id: IArmadaPositionId;
  netDeposits: ITokenAmount;
  netDepositsUSD: IFiatCurrencyAmount;
  pool: IArmadaVault;
  rewards: object[];
  shares: ITokenAmount;
  type: Armada;
  withdrawals: object[];
  withdrawalsAmount: ITokenAmount;
  withdrawalsAmountUSD: IFiatCurrencyAmount;
}>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:71](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L71)

## Description

Zod schema for IArmadaPosition
