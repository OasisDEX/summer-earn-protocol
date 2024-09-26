import { BigDecimal } from '@graphprotocol/graph-ts'
import { IRateProvider } from '../../generated/EntryPoint/IRateProvider'
import { BaseVaultProduct } from './BaseVaultProduct'

export class GenericVaultProduct extends BaseVaultProduct {
  getSharePrice(): BigDecimal {
    if (this.oracle === null) {
      return BigDecimal.zero()
    }
    const vault = IRateProvider.bind(this.oracle!)
    const tryGetRate = vault.try_getRate()
    if (tryGetRate.reverted) {
      return BigDecimal.zero()
    }

    return tryGetRate.value.toBigDecimal()
  }
}
