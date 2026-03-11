/**
 * TypeScript utilities mirroring @summerfi/percentage-solidity contracts.
 * Use these to format percentages for contract calls (e.g. TipJar allocation).
 *
 * @see packages/percentage/contracts/Percentage.sol
 * @see packages/percentage/contracts/PercentageUtils.sol
 */

const PERCENTAGE_DECIMALS = 18
const PERCENTAGE_FACTOR = 10n ** BigInt(PERCENTAGE_DECIMALS)
/** 100% in internal representation */
const PERCENTAGE_100 = 100n * PERCENTAGE_FACTOR

/**
 * Converts an integer percentage to the scaled format used by Percentage.sol.
 * @param percentage Human-readable percentage (e.g. 30 for 30%)
 * @returns Scaled value as hex string for contract ABI (e.g. 30 -> "30000000000000000000")
 *
 * Mirrors: PercentageUtils.fromIntegerPercentage / Percentage.toPercentage
 */
export function fromIntegerPercentage(percentage: number | bigint): string {
  const p = typeof percentage === 'bigint' ? percentage : BigInt(Math.floor(percentage))
  return (p * PERCENTAGE_FACTOR).toString()
}

/**
 * Converts a raw value to percentage format (value * 10^18).
 * Use for values that aren't integer percentages.
 *
 * Mirrors: Percentage.toPercentage(uint256)
 */
export function toPercentage(value: number | bigint): string {
  const v = typeof value === 'bigint' ? value : BigInt(Math.floor(value))
  return (v * PERCENTAGE_FACTOR).toString()
}

/**
 * Converts a fraction to percentage format.
 * @param numerator e.g. 1
 * @param denominator e.g. 2
 * @returns 50% as "50000000000000000000"
 *
 * Mirrors: PercentageUtils.fromFraction(numerator, denominator)
 */
export function fromFraction(numerator: number | bigint, denominator: number | bigint): string {
  const num = typeof numerator === 'bigint' ? numerator : BigInt(numerator)
  const den = typeof denominator === 'bigint' ? denominator : BigInt(denominator)
  if (den === 0n) throw new Error('fromFraction: denominator cannot be zero')
  return ((num * PERCENTAGE_FACTOR * 100n) / den).toString()
}

/**
 * Applies percentage to an amount: (amount * percentage) / 100.
 *
 * Mirrors: PercentageUtils.applyPercentage(amount, percentage)
 */
export function applyPercentage(amount: bigint, percentageScaled: bigint | string): bigint {
  const p = typeof percentageScaled === 'string' ? BigInt(percentageScaled) : percentageScaled
  return (amount * p) / PERCENTAGE_100
}

/**
 * Validates that a scaled percentage is in range [0, 100%].
 *
 * Mirrors: PercentageUtils.isPercentageInRange
 */
export function isPercentageInRange(percentageScaled: bigint | string): boolean {
  const p = typeof percentageScaled === 'string' ? BigInt(percentageScaled) : percentageScaled
  return p >= 0n && p <= PERCENTAGE_100
}

export { PERCENTAGE_DECIMALS, PERCENTAGE_FACTOR, PERCENTAGE_100 }
