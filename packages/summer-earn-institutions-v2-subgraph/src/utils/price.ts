import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { BigDecimalConstants } from '../common/constants'

/**
 * Convert a Price(baseAmount, quoteAmount) tuple into a BigDecimal representing
 * exchange-asset per underlying. Returns null-equivalent (BigDecimalConstants.ZERO) when the
 * base amount is zero so callers can decide whether to leave the field null.
 */
export function exchangeRateAsDecimal(base: BigInt, quote: BigInt): BigDecimal {
  if (base.equals(BigInt.fromI32(0))) {
    return BigDecimalConstants.ZERO
  }
  return quote.toBigDecimal().div(base.toBigDecimal())
}
