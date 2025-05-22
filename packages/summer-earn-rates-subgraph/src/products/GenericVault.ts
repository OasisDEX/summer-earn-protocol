import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { IRateProvider } from '../../generated/EntryPoint/IRateProvider'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { TvlData } from '../models/TvlData'
import { BaseVaultProduct } from './BaseVaultProduct'
export class GenericVaultProduct extends BaseVaultProduct {
  getSharePrice(): BigDecimal {
    if (this.oracle === null) {
      return BigDecimalConstants.ZERO
    }
    const vault = IRateProvider.bind(this.oracle!)
    const tryGetRate = vault.try_getRate()
    if (tryGetRate.reverted) {
      return BigDecimalConstants.ZERO
    }

    return tryGetRate.value.toBigDecimal()
  }

  getTvl(currentTimestamp: BigInt, currentBlock: BigInt): TvlData {
    return new TvlData(BigIntConstants.ZERO, BigDecimalConstants.ZERO, BigDecimalConstants.ZERO)
  }
}
