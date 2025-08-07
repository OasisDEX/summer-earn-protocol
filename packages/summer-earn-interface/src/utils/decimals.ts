import { formatUnits, parseUnits } from 'viem'

/**
 * Converts a user-friendly decimal input to wei units
 * @param value - The decimal value as string (e.g., "1.5")
 * @param decimals - Token decimals (e.g., 18 for most tokens)
 * @returns BigInt representation in wei
 */
export function parseDecimalInput(value: string, decimals: number): bigint {
  if (!value || value === '') return BigInt(0)

  try {
    return parseUnits(value, decimals)
  } catch (error) {
    console.error('Error parsing decimal input:', error)
    return BigInt(0)
  }
}

/**
 * Converts wei units to user-friendly decimal display
 * @param value - BigInt value in wei
 * @param decimals - Token decimals
 * @param maxDecimals - Max decimal places to show (default: 6)
 * @returns Formatted string
 */
export function formatDecimalOutput(
  value: bigint,
  decimals: number,
  maxDecimals: number = 6,
): string {
  try {
    // Handle MAX_UINT256 specially to avoid scientific notation
    if (value === MAX_UINT256) {
      return 'MAX'
    }

    const formatted = formatUnits(value, decimals)
    const num = parseFloat(formatted)

    // If it's exactly zero, return "0"
    if (num === 0) return '0'

    // Check for scientific notation and handle very large numbers
    if (formatted.includes('e') || num > 1e15) {
      // For very large numbers, show a truncated version
      return formatLargeNumber(value, decimals)
    }

    // If it's a whole number, don't show decimals
    if (num % 1 === 0) return num.toLocaleString('en-US')

    // For very small numbers, use more decimal places
    if (num > 0 && num < 0.000001) {
      const significantDecimals = Math.max(6, decimals - Math.floor(Math.log10(num)))
      return parseFloat(num.toFixed(Math.min(significantDecimals, 18))).toLocaleString('en-US', {
        minimumFractionDigits: 0,
        maximumFractionDigits: Math.min(significantDecimals, 18),
      })
    }

    // Otherwise, limit decimal places
    return parseFloat(num.toFixed(maxDecimals)).toLocaleString('en-US', {
      minimumFractionDigits: 0,
      maximumFractionDigits: maxDecimals,
    })
  } catch (error) {
    console.error('Error formatting decimal output:', error)
    return '0'
  }
}

/**
 * Maximum uint256 value for unlimited approvals/withdrawals
 */
export const MAX_UINT256 = BigInt(
  '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
)

/**
 * Formats large numbers with K, M, B suffixes
 */
export function formatLargeNumber(value: bigint, decimals: number): string {
  const num = parseFloat(formatUnits(value, decimals))

  if (num >= 1_000_000_000) {
    return (
      (num / 1_000_000_000).toLocaleString('en-US', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      }) + 'B'
    )
  } else if (num >= 1_000_000) {
    return (
      (num / 1_000_000).toLocaleString('en-US', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      }) + 'M'
    )
  } else if (num >= 1_000) {
    return (
      (num / 1_000).toLocaleString('en-US', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      }) + 'K'
    )
  }

  return formatDecimalOutput(value, decimals)
}
