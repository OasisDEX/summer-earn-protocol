# Interface: TransactionInfo

Defined in: [sdk/sdk-common/src/orders/common/types/TransactionInfo.ts:8](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/common/types/TransactionInfo.ts#L8)

TransactionInfo

## Description

Contains the low level transaction plus a description of what the transaction is for.
             This could be used to display the transaction to the user.

## Properties

### description

```ts
description: string;
```

Defined in: [sdk/sdk-common/src/orders/common/types/TransactionInfo.ts:12](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/common/types/TransactionInfo.ts#L12)

#### Description

High-level description of the transaction

***

### transaction

```ts
transaction: Transaction;
```

Defined in: [sdk/sdk-common/src/orders/common/types/TransactionInfo.ts:10](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/common/types/TransactionInfo.ts#L10)

#### Description

Low level transaction that can be sent to the blockchain
