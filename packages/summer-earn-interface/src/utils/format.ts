/**
 * Number-domain display formatters. The bigint/wei domain lives in ./decimals —
 * use formatTokenAmount / formatWadPercent (re-exported below) for on-chain values.
 * Display-only: never feed results into parseUnits, input values, or contract args.
 */

export {
  formatDecimalOutput as formatTokenAmount,
  formatLargeNumber,
  formatPercentage as formatWadPercent,
} from './decimals'

interface FormatNumberOptions {
  /** minimumFractionDigits (default 0) */
  min?: number
  /** maximumFractionDigits (default 2) */
  max?: number
}

export function formatNumber(value: number | string, opts: FormatNumberOptions = {}): string {
  const num = typeof value === 'string' ? Number(value) : value
  if (!Number.isFinite(num)) return '—'
  const { min = 0, max = 2 } = opts
  return num.toLocaleString('en-US', {
    minimumFractionDigits: min,
    maximumFractionDigits: Math.max(min, max),
  })
}

/** Formats an already-scaled percentage number: 12.345 → "12.35%". NOT for WAD bigints. */
export function formatPercent(value: number, maxDecimals: number = 2): string {
  if (!Number.isFinite(value)) return '—'
  return `${formatNumber(value, { max: maxDecimals })}%`
}

/** Compact K/M/B notation for plain numbers: 1234567 → "1.23M". */
export function formatCompact(value: number, maxDecimals: number = 2): string {
  if (!Number.isFinite(value)) return '—'
  const abs = Math.abs(value)
  if (abs >= 1_000_000_000)
    return `${formatNumber(value / 1_000_000_000, { min: maxDecimals, max: maxDecimals })}B`
  if (abs >= 1_000_000)
    return `${formatNumber(value / 1_000_000, { min: maxDecimals, max: maxDecimals })}M`
  if (abs >= 1_000) return `${formatNumber(value / 1_000, { min: maxDecimals, max: maxDecimals })}K`
  return formatNumber(value, { max: maxDecimals })
}
