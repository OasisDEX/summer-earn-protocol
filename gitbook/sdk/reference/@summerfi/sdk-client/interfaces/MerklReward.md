# Interface: MerklReward

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:135](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L135)

Represents a Merkl reward for a user

## Properties

### amount

```ts
amount: string;
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:143](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L143)

The reward amount

***

### breakdowns

```ts
breakdowns: Record<ChainId, Record<AddressValue, MerklRewardBreakdown>>;
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:151](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L151)

Breakdown of the reward into components

***

### claimed

```ts
claimed: string;
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:145](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L145)

The claimed amount

***

### pending

```ts
pending: string;
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:147](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L147)

The pending amount

***

### proofs

```ts
proofs: string[];
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:149](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L149)

The merkle proofs for claiming

***

### recipient

```ts
recipient: string;
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:141](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L141)

The recipient address

***

### root

```ts
root: string;
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:139](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L139)

The merkle root for the reward

***

### token

```ts
token: MerklApiToken;
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:137](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L137)

The token address for the reward

***

### unknownCampaigns

```ts
unknownCampaigns: MerklApiRewardBreakdown[];
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:153](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L153)

List of unknown campaign breakdowns
