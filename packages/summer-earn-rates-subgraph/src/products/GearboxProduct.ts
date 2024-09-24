import { Address, BigDecimal, BigInt, log } from '@graphprotocol/graph-ts'
import { GearboxPool } from '../../generated/EntryPoint/GearboxPool'
import { Product } from '../models/Product'
import { BigDecimalConstants } from '../constants/common'


export class GearboxProduct extends Product {
    getRate(currentTimestamp: BigInt): BigDecimal {
      const pool = GearboxPool.bind(this.address);
      const tryRate = pool.try_supplyRate();
      if (tryRate.reverted) {
        return BigDecimal.zero();
      }
      return tryRate.value.toBigDecimal().times(BigDecimalConstants.HUNDRED).div(BigDecimalConstants.RAY);
    }
  }
  