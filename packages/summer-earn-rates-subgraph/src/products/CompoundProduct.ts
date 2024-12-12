import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { Comet } from '../../generated/EntryPoint/Comet'
import { BigDecimalConstants } from '../constants/common'
import { Product } from '../models/Product'

export class CompoundProduct extends Product {
  getRate(currentTimestamp: BigInt, currentBlock: BigInt): BigDecimal {
    if (currentBlock.lt(this.startBlock)) {
      return BigDecimalConstants.ZERO
    }
    const comet = Comet.bind(this.poolAddress)
    const tryUtilization = comet.try_getUtilization()
    if (tryUtilization.reverted) {
      return BigDecimal.zero()
    }
    const utilization = tryUtilization.value
    const trySupplyRate = comet.try_getSupplyRate(utilization)
    if (trySupplyRate.reverted) {
      return BigDecimal.zero()
    }
    return trySupplyRate.value
      .toBigDecimal()
      .times(BigDecimalConstants.SECONDS_PER_YEAR.times(BigDecimalConstants.HUNDRED))
      .div(BigDecimalConstants.WAD)
  }
}
