import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'

/**
 * Converts an amount in base units to WAD units, based on the given precision.
 * @param {BigInt} amountInBaseUnit - The amount in base units to convert.
 * @param {BigInt} precision - The precision of the token.
 * @returns {BigInt} - The amount in WAD units.
 */
export function formatAmount(amountInBaseUnit: BigInt, decimals: BigInt): BigDecimal {
  const len = decimals.toI32() + 1
  const power = BigDecimal.fromString('10'.padEnd(len, '0'))

  return BigDecimal.fromString(amountInBaseUnit.toString()).div(power)
}
