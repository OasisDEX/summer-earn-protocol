import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { MoonwellToken } from '../../generated/EntryPoint/MoonwellToken'
import { BigDecimalConstants } from '../constants/common'
import { Product } from '../models/Product'

export class MoonwellProduct extends Product {
  getRate(currentTimestamp: BigInt, currentBlock: BigInt): BigDecimal {
    const vault = MoonwellToken.bind(this.poolAddress)
    const trySupplyRatePerTimestamp = vault.try_supplyRatePerTimestamp()

    if (trySupplyRatePerTimestamp.reverted) {
      return BigDecimal.zero()
    }

    const apr = trySupplyRatePerTimestamp.value
      .toBigDecimal()
      .times(BigDecimalConstants.SECONDS_PER_YEAR.times(BigDecimalConstants.HUNDRED))
      .div(BigDecimalConstants.WAD)

    return apr
  }
}
