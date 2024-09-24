import { Address, BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { Comet } from '../../generated/EntryPoint/Comet'
import { Token } from '../../generated/schema'
import { BigDecimalConstants } from '../constants/common'
import { Product } from '../models/Product'

export class CompoundProduct extends Product {
  constructor(token: Token, poolAddress: Address, startBlock: BigInt, name: string) {
    super(token, poolAddress, startBlock, name)
  }
  getRate(currentTimestamp: BigInt): BigDecimal {
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
