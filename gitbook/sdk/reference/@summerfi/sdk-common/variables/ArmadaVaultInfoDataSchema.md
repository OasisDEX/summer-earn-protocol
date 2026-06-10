# Variable: ArmadaVaultInfoDataSchema

```ts
const ArmadaVaultInfoDataSchema: ZodObject<{
  apy: ZodType<IPercentage | null, ZodTypeDef, IPercentage | null>;
  apys: ZodObject<{
     live: ZodType<IPercentage | null, ZodTypeDef, IPercentage | null>;
     sma24h: ZodType<IPercentage | null, ZodTypeDef, IPercentage | null>;
     sma30day: ZodType<IPercentage | null, ZodTypeDef, IPercentage | null>;
     sma7day: ZodType<IPercentage | null, ZodTypeDef, IPercentage | null>;
   }, "strip", ZodTypeAny, {
     live: IPercentage | null;
     sma24h: IPercentage | null;
     sma30day: IPercentage | null;
     sma7day: IPercentage | null;
   }, {
     live: IPercentage | null;
     sma24h: IPercentage | null;
     sma30day: IPercentage | null;
     sma7day: IPercentage | null;
  }>;
  assetToken: ZodType<ITokenStanalone, ZodTypeDef, ITokenStanalone>;
  depositCap: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  id: ZodType<IArmadaVaultId, ZodTypeDef, IArmadaVaultId>;
  merklRewards: ZodOptional<ZodArray<ZodObject<{
     dailyEmission: ZodString;
     token: ZodType<ITokenStanalone, ZodTypeDef, ITokenStanalone>;
   }, "strip", ZodTypeAny, {
     dailyEmission: string;
     token: ITokenStanalone;
   }, {
     dailyEmission: string;
     token: ITokenStanalone;
  }>, "many">>;
  rewardsApys: ZodOptional<ZodArray<ZodObject<{
     apy: ZodType<IPercentage | null, ZodTypeDef, IPercentage | null>;
     token: ZodType<ITokenStanalone, ZodTypeDef, ITokenStanalone>;
   }, "strip", ZodTypeAny, {
     apy: IPercentage | null;
     token: ITokenStanalone;
   }, {
     apy: IPercentage | null;
     token: ITokenStanalone;
  }>, "many">>;
  sharePrice: ZodType<IPrice, ZodTypeDef, IPrice>;
  token: ZodType<ITokenStanalone, ZodTypeDef, ITokenStanalone>;
  totalDeposits: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  totalShares: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  tvlUsd: ZodType<IFiatCurrencyAmount, ZodTypeDef, IFiatCurrencyAmount>;
  type: ZodLiteral<Armada>;
}, "strip", ZodTypeAny, {
  apy: IPercentage | null;
  apys: {
     live: IPercentage | null;
     sma24h: IPercentage | null;
     sma30day: IPercentage | null;
     sma7day: IPercentage | null;
  };
  assetToken: ITokenStanalone;
  depositCap: ITokenAmount;
  id: IArmadaVaultId;
  merklRewards?: object[];
  rewardsApys?: object[];
  sharePrice: IPrice;
  token: ITokenStanalone;
  totalDeposits: ITokenAmount;
  totalShares: ITokenAmount;
  tvlUsd: IFiatCurrencyAmount;
  type: Armada;
}, {
  apy: IPercentage | null;
  apys: {
     live: IPercentage | null;
     sma24h: IPercentage | null;
     sma30day: IPercentage | null;
     sma7day: IPercentage | null;
  };
  assetToken: ITokenStanalone;
  depositCap: ITokenAmount;
  id: IArmadaVaultId;
  merklRewards?: object[];
  rewardsApys?: object[];
  sharePrice: IPrice;
  token: ITokenStanalone;
  totalDeposits: ITokenAmount;
  totalShares: ITokenAmount;
  tvlUsd: IFiatCurrencyAmount;
  type: Armada;
}>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts:66](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts#L66)

## Description

Zod schema for IArmadaVaultInfo
