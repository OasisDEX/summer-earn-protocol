import { formatUnits, parseUnits } from 'viem'

// Ported from packages/summer-earn-interface/src/utils/decimals.ts and adapted
// for DCA-specific formatting (bps as percentage, feed prices, share/asset
// display). NEVER convert raw token amounts via Number().

export const MAX_UINT256 = BigInt(
  '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
)

export const MAX_UINT160 = (1n << 160n) - 1n

export function parseDecimalInput(value: string, decimals: number): bigint {
  if (!value || value === '') return 0n
  try {
    return parseUnits(value, decimals)
  } catch (e) {
    console.error('parseDecimalInput failed:', e)
    return 0n
  }
}

export function formatLargeNumber(value: bigint, decimals: number): string {
  const num = parseFloat(formatUnits(value, decimals))
  if (num >= 1_000_000_000) {
    return (num / 1_000_000_000).toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }) + 'B'
  }
  if (num >= 1_000_000) {
    return (num / 1_000_000).toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }) + 'M'
  }
  if (num >= 1_000) {
    return (num / 1_000).toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }) + 'K'
  }
  return formatDecimalOutput(value, decimals)
}

export function formatDecimalOutput(value: bigint, decimals: number, maxDecimals = 6): string {
  try {
    if (value === MAX_UINT256) return 'MAX'
    const formatted = formatUnits(value, decimals)
    const num = parseFloat(formatted)
    if (num === 0) return '0'
    if (formatted.includes('e') || num > 1e15) return formatLargeNumber(value, decimals)
    if (num % 1 === 0) return num.toLocaleString('en-US')
    if (num > 0 && num < 0.000001) {
      const sig = Math.max(6, decimals - Math.floor(Math.log10(num)))
      return parseFloat(num.toFixed(Math.min(sig, 18))).toLocaleString('en-US', {
        minimumFractionDigits: 0,
        maximumFractionDigits: Math.min(sig, 18),
      })
    }
    return parseFloat(num.toFixed(maxDecimals)).toLocaleString('en-US', {
      minimumFractionDigits: 0,
      maximumFractionDigits: maxDecimals,
    })
  } catch (e) {
    console.error('formatDecimalOutput failed:', e)
    return '0'
  }
}

// slippageBps in StrategyConfig: 0..10000 representing 0%..100%.
export function formatBpsAsPercent(bps: bigint, maxDecimals = 2): string {
  const n = Number(bps) / 100
  return `${n.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: maxDecimals })}%`
}

// Chainlink feed values are stored at the feed's `decimals()` precision
// (typically 8 for USD pairs).
export function formatFeedPrice(raw: bigint, feedDecimals: number, maxDecimals = 4): string {
  return formatDecimalOutput(raw, feedDecimals, maxDecimals)
}

export function formatUnixDate(unix: bigint): string {
  if (unix === 0n) return '—'
  const ms = Number(unix) * 1000
  return new Date(ms).toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function shortAddress(addr: string, prefix = 6, suffix = 4): string {
  if (!addr || addr.length < prefix + suffix + 2) return addr
  return `${addr.slice(0, prefix)}…${addr.slice(-suffix)}`
}
