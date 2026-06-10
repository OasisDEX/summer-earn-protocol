# Interface: EnrichedOrder

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:1028

An order with the total fee added.

## Extends

- `Order`

## Properties

### appData

```ts
appData: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:475

This field comes in two forms for backward compatibility. The hash form will eventually stop being accepted.

#### Inherited from

```ts
Order.appData
```

***

### appDataHash?

```ts
optional appDataHash: string | null;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:480

May be set for debugging purposes. If set, this field is compared to what the backend internally calculates as the app data hash based on the contents of `appData`. If the hash does not match, an error is returned. If this field is set, then `appData` **MUST** be a string encoding of a JSON object.

#### Inherited from

```ts
Order.appDataHash
```

***

### ~~availableBalance?~~

```ts
optional availableBalance: string | null;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:511

Unused field that is currently always set to `null` and will be removed in the future.

#### Deprecated

#### Inherited from

```ts
Order.availableBalance
```

***

### buyAmount

```ts
buyAmount: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:434

see `OrderParameters::buyAmount`

#### Inherited from

```ts
Order.buyAmount
```

***

### buyToken

```ts
buyToken: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:422

see `OrderParameters::buyToken`

#### Inherited from

```ts
Order.buyToken
```

***

### buyTokenBalance?

```ts
optional buyTokenBalance: BuyTokenDestination;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:458

see `OrderParameters::buyTokenBalance`

#### Inherited from

```ts
Order.buyTokenBalance
```

***

### class

```ts
class: OrderClass;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:503

#### Inherited from

```ts
Order.class
```

***

### creationDate

```ts
creationDate: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:502

Creation time of the order. Encoded as ISO 8601 UTC.

#### Inherited from

```ts
Order.creationDate
```

***

### ethflowData?

```ts
optional ethflowData: EthflowData;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:552

#### Inherited from

```ts
Order.ethflowData
```

***

### executedBuyAmount

```ts
executedBuyAmount: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:526

The total amount of `buyToken` that has been executed for this order.

#### Inherited from

```ts
Order.executedBuyAmount
```

***

### executedFee?

```ts
optional executedFee: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:569

Total fee charged for execution of the order. Contains network fee and protocol fees. This takes into account the historic static fee signed by the user and the new dynamic fee computed by solvers.

#### Inherited from

```ts
Order.executedFee
```

***

### executedFeeAmount

```ts
executedFeeAmount: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:531

[DEPRECATED] The total amount of the user signed `fee` that have been executed for this order. This value is only non-negative for very old orders.

#### Inherited from

```ts
Order.executedFeeAmount
```

***

### executedFeeToken?

```ts
optional executedFeeToken: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:573

Token the executed fee was captured in.

#### Inherited from

```ts
Order.executedFeeToken
```

***

### executedSellAmount

```ts
executedSellAmount: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:516

The total amount of `sellToken` that has been transferred from the user for this order so far.

#### Inherited from

```ts
Order.executedSellAmount
```

***

### executedSellAmountBeforeFees

```ts
executedSellAmountBeforeFees: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:521

The total amount of `sellToken` that has been transferred from the user for this order so far minus tokens that were transferred as part of the signed `fee` of the order. This is only relevant for old orders because now all orders have a signed `fee` of 0 and solvers compute an appropriate fee dynamically at the time of the order execution.

#### Inherited from

```ts
Order.executedSellAmountBeforeFees
```

***

### feeAmount

```ts
feeAmount: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:442

see `OrderParameters::feeAmount`

#### Inherited from

```ts
Order.feeAmount
```

***

### from?

```ts
optional from: string | null;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:465

If set, the backend enforces that this address matches what is decoded as the *signer* of the signature. This helps catch errors with invalid signature encodings as the backend might otherwise silently work with an unexpected address that for example does not have any balance.

#### Inherited from

```ts
Order.from
```

***

### fullAppData?

```ts
optional fullAppData: string | null;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:578

Full `appData`, which the contract-level `appData` is a hash of. See `OrderCreation` for more information.

#### Inherited from

```ts
Order.fullAppData
```

***

### invalidated

```ts
invalidated: boolean;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:535

Has this order been invalidated?

#### Inherited from

```ts
Order.invalidated
```

***

### isLiquidityOrder?

```ts
optional isLiquidityOrder: boolean;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:551

Liquidity orders are functionally the same as normal smart contract
orders but are not placed with the intent of actively getting
traded. Instead they facilitate the trade of normal orders by
allowing them to be matched against liquidity orders which uses less
gas and can have better prices than external liquidity.

As such liquidity orders will only be used in order to improve
settlement of normal orders. They should not be expected to be
traded otherwise and should not expect to get surplus.

#### Inherited from

```ts
Order.isLiquidityOrder
```

***

### kind

```ts
kind: OrderKind;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:446

see `OrderParameters::kind`

#### Inherited from

```ts
Order.kind
```

***

### onchainOrderData?

```ts
optional onchainOrderData: OnchainOrderData;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:564

There is some data only available for orders that are placed on-chain. This data can be found in this object.

#### Inherited from

```ts
Order.onchainOrderData
```

***

### onchainUser?

```ts
optional onchainUser: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:559

This represents the actual trader of an on-chain order.
### ethflow orders
In this case, the `owner` would be the `EthFlow` contract and *not* the actual trader.

#### Inherited from

```ts
Order.onchainUser
```

***

### owner

```ts
owner: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:504

#### Inherited from

```ts
Order.owner
```

***

### partiallyFillable

```ts
partiallyFillable: boolean;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:450

see `OrderParameters::partiallyFillable`

#### Inherited from

```ts
Order.partiallyFillable
```

***

### quoteId?

```ts
optional quoteId: number | null;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:470

Orders can optionally include a quote ID. This way the order can be linked to a quote and enable providing more metadata when analysing order slippage.

#### Inherited from

```ts
Order.quoteId
```

***

### receiver?

```ts
optional receiver: string | null;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:426

see `OrderParameters::receiver`

#### Inherited from

```ts
Order.receiver
```

***

### sellAmount

```ts
sellAmount: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:430

see `OrderParameters::sellAmount`

#### Inherited from

```ts
Order.sellAmount
```

***

### sellToken

```ts
sellToken: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:418

see `OrderParameters::sellToken`

#### Inherited from

```ts
Order.sellToken
```

***

### sellTokenBalance?

```ts
optional sellTokenBalance: SellTokenSource;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:454

see `OrderParameters::sellTokenBalance`

#### Inherited from

```ts
Order.sellTokenBalance
```

***

### signature

```ts
signature: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:460

#### Inherited from

```ts
Order.signature
```

***

### signingScheme

```ts
signingScheme: SigningScheme;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:459

#### Inherited from

```ts
Order.signingScheme
```

***

### status

```ts
status: OrderStatus;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:539

Order status.

#### Inherited from

```ts
Order.status
```

***

### totalFee

```ts
totalFee: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:1029

***

### uid

```ts
uid: string;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:505

#### Inherited from

```ts
Order.uid
```

***

### validTo

```ts
validTo: number;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-book@2.1.0/node\_modules/@cowprotocol/sdk-order-book/dist/index.d.ts:438

see `OrderParameters::validTo`

#### Inherited from

```ts
Order.validTo
```
