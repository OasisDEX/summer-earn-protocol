# Variable: UserDataSchema

```ts
const UserDataSchema: ZodObject<{
  chainInfo: ZodType<IChainInfo, ZodTypeDef, IChainInfo>;
  wallet: ZodType<IWallet, ZodTypeDef, IWallet>;
}, "strip", ZodTypeAny, {
  chainInfo: IChainInfo;
  wallet: IWallet;
}, {
  chainInfo: IChainInfo;
  wallet: IWallet;
}>;
```

Defined in: [sdk/sdk-common/src/user/interfaces/IUser.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/user/interfaces/IUser.ts#L26)

Zod schema for the data part of IUser
