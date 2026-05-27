// Mirrors packages/price-utils/contracts/{Types,Utils}.sol — the on-chain
// Price{ baseAmount, quoteAmount } and quote() helper. For a rounds-vault
// receipt of `receiptAmount` (in `asset()` decimals), the claimable amount
// of exchange-asset is `receiptAmount * base / quote`.

export interface ExchangeRate {
  base: bigint
  quote: bigint
}

export function priceFromSubgraph(round: {
  exchangeRateBase?: string | null
  exchangeRateQuote?: string | null
}): ExchangeRate | null {
  if (!round.exchangeRateBase || !round.exchangeRateQuote) return null
  const base = BigInt(round.exchangeRateBase)
  const quote = BigInt(round.exchangeRateQuote)
  if (quote === 0n) return null
  return { base, quote }
}

export function quoteExchange(rate: ExchangeRate, receiptAmount: bigint): bigint {
  return (receiptAmount * rate.base) / rate.quote
}

export function invertExchange(rate: ExchangeRate): ExchangeRate {
  return { base: rate.quote, quote: rate.base }
}
