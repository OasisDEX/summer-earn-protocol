# Interface: MerklApiOpportunityRewardsRecordBreakdown

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:46](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L46)

Individual reward breakdown entry

## Properties

### amount

```ts
amount: string;
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:50](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L50)

Amount of tokens as string (to handle large numbers)

***

### campaignId

```ts
campaignId: string;
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:60](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L60)

ID of the campaign this reward belongs to

***

### dailyRewardsRecordId

```ts
dailyRewardsRecordId: string;
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:62](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L62)

ID of the daily rewards record this belongs to

***

### distributionType

```ts
distributionType: string;
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:54](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L54)

Type of distribution mechanism

***

### id

```ts
id: string;
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:56](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L56)

Unique identifier for this breakdown

***

### timestamp

```ts
timestamp: string;
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:58](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L58)

Timestamp when this reward was recorded

***

### token

```ts
token: MerklApiOpportunityRewardsRecordBreakdownToken;
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:48](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L48)

Token information for this reward

***

### value

```ts
value: number;
```

Defined in: [sdk/armada-protocol-common/src/common/types/MerklTypes.ts:52](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/armada-protocol-common/src/common/types/MerklTypes.ts#L52)

USD value of the reward amount
