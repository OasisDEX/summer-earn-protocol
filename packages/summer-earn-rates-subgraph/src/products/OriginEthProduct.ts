import { BigDecimal, log } from '@graphprotocol/graph-ts'
import { IRateProvider } from '../../generated/EntryPoint/IRateProvider'
import { BigDecimalConstants } from '../constants/common'
import { BaseVaultProduct } from './BaseVaultProduct'

export class OriginEthProduct extends BaseVaultProduct {
  getSharePrice(): BigDecimal {
    const vault = IRateProvider.bind(this.poolAddress)
    const tryGetRate = vault.try_rebasingCreditsPerTokenHighres()
    log.error('origin - tryGetRate: {}', [tryGetRate.reverted.toString()])
    if (tryGetRate.reverted) {
      return BigDecimal.zero()
    }
    log.error('origin - tryGetRate: {}', [tryGetRate.value.toString()])
    return BigDecimalConstants.RAY.div(tryGetRate.value.toBigDecimal())
  }
}
