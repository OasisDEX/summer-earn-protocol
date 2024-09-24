import { Address, BigDecimal, BigInt, log } from '@graphprotocol/graph-ts'
import { Comet } from '../../generated/EntryPoint/Comet'
import { Product } from '../models/Product'
import { BigDecimalConstants } from '../constants/common'

export class CompoundProduct extends Product {
    getRate(currentTimestamp: BigInt): BigDecimal {
      const comet = Comet.bind(this.address);
      const tryUtilization = comet.try_getUtilization();
      if (tryUtilization.reverted) {
        return BigDecimal.zero();
      }
      const utilization = tryUtilization.value;
      const trySupplyRate = comet.try_getSupplyRate(utilization);
      if (trySupplyRate.reverted) {
        return BigDecimal.zero();
      }
      return trySupplyRate.value
        .toBigDecimal()
        .times(BigDecimalConstants.SECONDS_PER_YEAR.times(BigDecimalConstants.HUNDRED))
        .div(BigDecimalConstants.WAD);
    }
  }