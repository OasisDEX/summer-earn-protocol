import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { GearboxPool } from '../../generated/EntryPoint/GearboxPool'
import { BigDecimalConstants } from '../constants/common'
import { Product } from '../models/Product'

export class GearboxProduct extends Product {
  getRate(currentTimestamp: BigInt, currentBlock: BigInt): BigDecimal {
    if (currentBlock.lt(this.startBlock)) {
      return BigDecimalConstants.ZERO
    }
    const pool = GearboxPool.bind(this.poolAddress)
    const tryRate = pool.try_supplyRate()
    if (tryRate.reverted) {
      return BigDecimal.zero()
    }
    return tryRate.value
      .toBigDecimal()
      .times(BigDecimalConstants.HUNDRED)
      .div(BigDecimalConstants.RAY)
  }
}
