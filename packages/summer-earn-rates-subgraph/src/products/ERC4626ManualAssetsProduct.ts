import { Address, BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { ERC4626 } from '../../generated/EntryPoint/ERC4626'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { TvlData } from '../models/TvlData'
import { formatAmount } from '../utils/formatters'
import { getTokenPriceInUSD } from '../utils/price-helper'
import { BaseVaultProduct } from './BaseVaultProduct'

export class ERC4626ManualAssetsProduct extends BaseVaultProduct {
  getSharePrice(): BigDecimal {
    const vault = ERC4626.bind(this.poolAddress)
    const reyAssetsPerWad = vault.try_convertToAssets(BigIntConstants.WAD)

    if (reyAssetsPerWad.reverted) {
      return BigDecimalConstants.ZERO
    }

    const assetsPerWad = reyAssetsPerWad.value

    if (assetsPerWad.equals(BigIntConstants.ZERO)) {
      return BigDecimalConstants.ZERO
    }

    return assetsPerWad.toBigDecimal().div(BigDecimalConstants.WAD)
  }

  getTvl(currentTimestamp: BigInt, currentBlock: BigInt): TvlData {
    const vault = ERC4626.bind(this.poolAddress)
    const tryTotalAssets = vault.try_totalAssets()

    if (tryTotalAssets.reverted) {
      return new TvlData(BigIntConstants.ZERO, BigDecimalConstants.ZERO, BigDecimalConstants.ZERO)
    }

    const tokenAmountRaw = tryTotalAssets.value
    const tokenAmountNormalized = formatAmount(tokenAmountRaw, this.token.decimals)
    const tokenPriceInUsd = getTokenPriceInUSD(Address.fromBytes(this.token.address), currentBlock)
    const usdAmountNormalized = tokenAmountNormalized.times(tokenPriceInUsd.price)

    return new TvlData(tokenAmountRaw, tokenAmountNormalized, usdAmountNormalized)
  }
}
