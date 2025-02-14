import { BigDecimal } from '@graphprotocol/graph-ts'
import { BigDecimalConstants } from '../constants/common'

export function aprToApy(apr: BigDecimal): BigDecimal {
  // Convert APR from percentage to decimal (divide by 100)
  const aprDecimal = apr.div(BigDecimalConstants.HUNDRED)

  // Using Taylor series approximation for e^x since AssemblyScript doesn't have Math.exp
  // e^x ≈ 1 + x + x²/2! + x³/3! + x⁴/4! + x⁵/5!
  // This gives us good precision for typical interest rates

  const x2 = aprDecimal.times(aprDecimal).div(BigDecimal.fromString('2')) // x²/2!
  const x3 = aprDecimal.times(aprDecimal).times(aprDecimal).div(BigDecimal.fromString('6')) // x³/3!
  const x4 = aprDecimal
    .times(aprDecimal)
    .times(aprDecimal)
    .times(aprDecimal)
    .div(BigDecimal.fromString('24')) // x⁴/4!
  const x5 = aprDecimal
    .times(aprDecimal)
    .times(aprDecimal)
    .times(aprDecimal)
    .times(aprDecimal)
    .div(BigDecimal.fromString('120')) // x⁵/5!

  const eToX = BigDecimal.fromString('1').plus(aprDecimal).plus(x2).plus(x3).plus(x4).plus(x5)

  // Convert back to percentage
  return eToX.minus(BigDecimal.fromString('1')).times(BigDecimalConstants.HUNDRED)
}
