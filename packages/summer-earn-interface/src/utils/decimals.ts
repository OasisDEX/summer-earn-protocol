import { parseUnits, formatUnits } from 'viem'

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
  maxDecimals: number = 6
): string {
  try {
    const formatted = formatUnits(value, decimals)
    const num = parseFloat(formatted)
    
    // If it's exactly zero, return "0"
    if (num === 0) return '0'
    
    // If it's a whole number, don't show decimals
    if (num % 1 === 0) return num.toString()
    
    // For very small numbers, use more decimal places
    if (num > 0 && num < 0.000001) {
      const significantDecimals = Math.max(6, decimals - Math.floor(Math.log10(num)))
      return num.toFixed(Math.min(significantDecimals, 18)).replace(/\.?0+$/, '')
    }
    
    // Otherwise, limit decimal places
    return num.toFixed(maxDecimals).replace(/\.?0+$/, '')
  } catch (error) {
    console.error('Error formatting decimal output:', error)
    return '0'
  }
}

/**
 * Maximum uint256 value for unlimited approvals/withdrawals
 */
export const MAX_UINT256 = BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')

/**
 * Formats large numbers with K, M, B suffixes
 */
export function formatLargeNumber(value: bigint, decimals: number): string {
  const num = parseFloat(formatUnits(value, decimals))
  
  if (num >= 1_000_000_000) {
    return (num / 1_000_000_000).toFixed(2) + 'B'
  } else if (num >= 1_000_000) {
    return (num / 1_000_000).toFixed(2) + 'M'
  } else if (num >= 1_000) {
    return (num / 1_000).toFixed(2) + 'K'
  }
  
  return formatDecimalOutput(value, decimals)
}