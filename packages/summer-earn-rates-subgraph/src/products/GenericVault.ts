import { BigDecimal, log } from '@graphprotocol/graph-ts'
import { IRateProvider } from '../../generated/EntryPoint/IRateProvider'
import { BaseVaultProduct } from './BaseVaultProduct'

export class GenericVaultProduct extends BaseVaultProduct {
    getSharePrice(): BigDecimal {
        const vault = IRateProvider.bind(this.address);
        const tryGetRate = vault.try_getRate();
        if (tryGetRate.reverted) {
            return BigDecimal.zero();
        }

        return tryGetRate.value.toBigDecimal();
    }
}