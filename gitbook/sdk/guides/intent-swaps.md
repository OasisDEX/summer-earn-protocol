---
description: Intent-based, gasless, MEV-protected swaps via the CoW Protocol integration.
---

# Intent Swaps

> Applies to `@summer_fi/sdk-client` v2.3.0

The SDK supports intent-based swaps through a CoW Protocol integration, enabling gasless trading
with MEV protection. Intent swaps let you create limit orders that solvers execute when your
conditions are met.

Swap methods live under [`sdk.intentSwaps`](../reference/@summerfi/sdk-client/classes/SDKManager.md).

## Features

- **Gasless trading** — no gas to create an order (only for approval / wrapping if required).
- **MEV protection** — orders settle in batch auctions.
- **Limit orders** — set a price limit for your trade.
- **Partial fills** — orders may be partially filled if you allow it.
- **Native currency support** — automatic wrapping of native currency to its ERC-20 form (ETH → WETH).
- **Smart approvals** — automatic ERC-20 approval handling when required.

## Creating the SDK client

The intent-swap client is available on the standard SDK manager — create it with
[`makeSDK`](../reference/@summerfi/sdk-client/functions/makeSDK.md):

```typescript
import { makeSDK } from '@summer_fi/sdk-client'

export const sdk = makeSDK({
  apiDomainUrl: `https://summer.fi`,
  logging: process.env.NODE_ENV === 'development',
})
```

> The order-mutating methods (`sendOrder`, `cancelOrder`) sign and broadcast through a viem
> [`WalletClient`](https://viem.sh/docs/clients/wallet) and read state through a viem
> [`PublicClient`](https://viem.sh/docs/clients/public). Pass these clients in per call (see below).

## Flow

The intent swap process follows this flow:

1. **Quote** — get a quote for your desired parameters.
2. **Native currency wrapping** (if needed) — the required amount of native currency is wrapped to
   its ERC-20 form for use in the order.
3. **Token approval** (if needed) — ERC-20 tokens are approved for spending by CoW Protocol.
4. **Order submission** — the signed order is submitted to the CoW Protocol orderbook.
5. **Solver execution** — solvers compete to fill your order at the best price.
6. **Settlement** — your trade settles as part of a batch, with MEV protection.

## 1. Get a quote

`getSellOrderQuote` returns quote data including the `order` you later submit, the resolved
`fromAmount` / `toAmount`, and a `validTo` expiry.

```typescript
import { TokenAmount, ChainIds, Address } from '@summer_fi/sdk-client'
import { sdk } from './sdk'

const ethToken = await sdk.tokens.getTokenBySymbol({ symbol: 'ETH', chainId: ChainIds.Base })
const usdcToken = await sdk.tokens.getTokenBySymbol({ symbol: 'USDC', chainId: ChainIds.Base })

const ethAmount = TokenAmount.createFrom({ amount: '0.1', token: ethToken }) // 0.1 ETH

const quote = await sdk.intentSwaps.getSellOrderQuote({
  sender: Address.createFromEthereum({ value: '0x...' }), // your wallet address
  fromAmount: ethAmount,
  toToken: usdcToken,
  limitPrice: '3000', // optional: minimum price (USDC per ETH)
  partiallyFillable: false, // optional: allow partial fills
  receiver: Address.createFromEthereum({ value: '0x...' }), // optional: different receiver
  slippagePercentage: 1, // optional: max slippage in percent
})

console.log('Quote:', {
  fromAmount: quote.fromAmount.toString(),
  toAmount: quote.toAmount.toString(),
  validTo: new Date(quote.validTo * 1000),
})
```

> A quote does not guarantee execution at the quoted amounts — market conditions may change. It is
> valid until its `validTo` timestamp.

## 2. Send the order

`sendOrder` handles native-currency wrapping and token approvals as part of submission. It is a
state machine: call it in a loop, executing any returned transaction, until it reports `order_sent`.
It requires a viem `walletClient` and `publicClient` (and optionally an `account`).

```typescript
let orderId: string | undefined

do {
  const orderResult = await sdk.intentSwaps.sendOrder({
    sender: Address.createFromEthereum({ value: '0x...' }),
    fromAmount: quote.fromAmount,
    chainId: ChainIds.Base,
    order: quote.order,
    walletClient, // viem WalletClient
    publicClient, // viem PublicClient
    // account,   // optional viem Account
  })

  switch (orderResult.status) {
    case 'wrap_to_native':
      // wrap native currency (ETH) to its wrapped form (WETH)
      await walletClient.sendTransaction({
        to: orderResult.transactionInfo.transaction.target.value,
        data: orderResult.transactionInfo.transaction.calldata,
        value: BigInt(orderResult.transactionInfo.transaction.value),
      })
      break

    case 'allowance_needed':
      // approve token spending
      await walletClient.sendTransaction({
        to: orderResult.transactionInfo.transaction.target.value,
        data: orderResult.transactionInfo.transaction.calldata,
        value: BigInt(orderResult.transactionInfo.transaction.value),
      })
      break

    case 'order_sent':
      orderId = orderResult.orderId
      console.log('Order sent:', orderId)
      break
  }
} while (!orderId)
```

## 3. Check order status

`checkOrder` returns the order's current state, or `null` if it is not found.

```typescript
const orderInfo = await sdk.intentSwaps.checkOrder({
  chainId: ChainIds.Base,
  orderId,
})

if (orderInfo) {
  console.log('Order status:', orderInfo.order.status)
  console.log('Order details:', {
    sellToken: orderInfo.order.sellToken,
    buyToken: orderInfo.order.buyToken,
    sellAmount: orderInfo.order.sellAmount,
    buyAmount: orderInfo.order.buyAmount,
    validTo: new Date(orderInfo.order.validTo * 1000),
    executedBuyAmount: orderInfo.order.executedBuyAmount,
    executedSellAmount: orderInfo.order.executedSellAmount,
  })
} else {
  console.log('Order not found')
}
```

## 4. Cancel an order

Cancel an order before it is filled. Like `sendOrder`, cancellation is signed and broadcast and
requires a viem `walletClient` and `publicClient`.

```typescript
const cancelResult = await sdk.intentSwaps.cancelOrder({
  chainId: ChainIds.Base,
  orderId,
  walletClient,
  publicClient,
  // account, // optional viem Account
})

console.log('Cancel result:', cancelResult.result)
```

## Supported networks

Intent swaps are currently supported on:

- Ethereum Mainnet (ChainId: `1`)
- Base (ChainId: `8453`)
- Arbitrum One (ChainId: `42161`)
- Optimism (ChainId: `10`)

## Error handling

The SDK surfaces common failures as errors you can branch on by message:

```typescript
try {
  const quote = await sdk.intentSwaps.getSellOrderQuote({
    sender: walletAddress,
    fromAmount: swapAmount,
    toToken: usdcToken,
  })
} catch (error) {
  if (error.message.includes('Unsupported chainId')) {
    console.error('Chain not supported for intent swaps')
  } else if (error.message.includes('Insufficient balance')) {
    console.error('Not enough token balance')
  } else {
    console.error('Quote failed:', error.message)
  }
}
```
