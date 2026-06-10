# Variable: ArmadaDepositDataSchema

```ts
const ArmadaDepositDataSchema: ZodObject<{
  amount: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  amountUsd: ZodType<IFiatCurrencyAmount, ZodTypeDef, IFiatCurrencyAmount>;
  from: ZodType<`0x${string}`, ZodTypeDef, `0x${string}`>;
  timestamp: ZodNumber;
  to: ZodType<`0x${string}`, ZodTypeDef, `0x${string}`>;
  txHash: ZodType<`0x${string}`, ZodTypeDef, `0x${string}`>;
  vaultBalance: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  vaultBalanceUsd: ZodType<IFiatCurrencyAmount, ZodTypeDef, IFiatCurrencyAmount>;
}, "strip", ZodTypeAny, {
  amount: ITokenAmount;
  amountUsd: IFiatCurrencyAmount;
  from: `0x${string}`;
  timestamp: number;
  to: `0x${string}`;
  txHash: `0x${string}`;
  vaultBalance: ITokenAmount;
  vaultBalanceUsd: IFiatCurrencyAmount;
}, {
  amount: ITokenAmount;
  amountUsd: IFiatCurrencyAmount;
  from: `0x${string}`;
  timestamp: number;
  to: `0x${string}`;
  txHash: `0x${string}`;
  vaultBalance: ITokenAmount;
  vaultBalanceUsd: IFiatCurrencyAmount;
}>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDeposit.ts:10](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDeposit.ts#L10)

## Description

Zod schema for IArmadaDeposit
