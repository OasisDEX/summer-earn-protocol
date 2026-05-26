import { formatDecimalOutput } from '@/lib/format'
import { type ExchangeRate, quoteExchange } from '@/lib/rounds/rate'

interface Props {
  rate: ExchangeRate | null
  receiptAmount?: bigint
  underlyingDecimals: number
  exchangeDecimals: number
  underlyingSymbol: string
  exchangeSymbol: string
}

export function ExchangeRateDisplay({
  rate,
  receiptAmount,
  underlyingDecimals,
  exchangeDecimals,
  underlyingSymbol,
  exchangeSymbol,
}: Props) {
  if (!rate || rate.quote === 0n) {
    return <span className="font-mono text-xs text-[var(--text-3)]">Rate pending</span>
  }

  const unitReceipt = 10n ** BigInt(underlyingDecimals)
  const perUnit = quoteExchange(rate, unitReceipt)
  const lineA = `${formatDecimalOutput(perUnit, exchangeDecimals, 6)} ${exchangeSymbol} per 1 ${underlyingSymbol}`

  if (!receiptAmount || receiptAmount === 0n) {
    return <span className="font-mono text-xs text-[var(--text-3)]">{lineA}</span>
  }

  const out = quoteExchange(rate, receiptAmount)
  return (
    <span className="font-mono text-xs text-[var(--text-3)]">
      {lineA} · {formatDecimalOutput(out, exchangeDecimals, 6)} {exchangeSymbol} claimable
    </span>
  )
}
