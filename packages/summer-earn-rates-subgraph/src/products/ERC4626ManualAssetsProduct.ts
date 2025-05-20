import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { ERC4626 } from '../../generated/EntryPoint/ERC4626'
import { BaseVaultProduct } from './BaseVaultProduct'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'



export class ERC4626ManualAssetsProduct extends BaseVaultProduct {
  getSharePrice(): BigDecimal {
    const vault = ERC4626.bind(this.poolAddress)
    const reyAssetsPerWad = vault.try_convertToAssets(BigIntConstants.WAD)

    if (reyAssetsPerWad.reverted) {
      return BigDecimal.zero()
    }

    const assetsPerWad = reyAssetsPerWad.value

    if (assetsPerWad.equals(BigInt.zero())) {
      return BigDecimal.zero()
    }

    return assetsPerWad.toBigDecimal().div(BigDecimalConstants.WAD)
  }
}
