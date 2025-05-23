import { Address, BigDecimal, BigInt, log } from '@graphprotocol/graph-ts'
import { ERC4626 } from '../../generated/EntryPoint/ERC4626'
import { IRateProvider } from '../../generated/EntryPoint/IRateProvider'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { TvlData } from '../models/TvlData'
import { formatAmount } from '../utils/formatters'
import { getTokenPriceInUSD } from '../utils/price-helper'
import { BaseVaultProduct } from './BaseVaultProduct'

export class OriginEthProduct extends BaseVaultProduct {
  getSharePrice(): BigDecimal {
    const vault = IRateProvider.bind(this.poolAddress)
    const tryGetRate = vault.try_rebasingCreditsPerTokenHighres()
    log.error('origin - tryGetRate: {}', [tryGetRate.reverted.toString()])
    if (tryGetRate.reverted) {
      return BigDecimalConstants.ZERO
    }
    log.error('origin - tryGetRate: {}', [tryGetRate.value.toString()])
    return BigDecimalConstants.RAY.div(tryGetRate.value.toBigDecimal())
  }

  getTvl(currentTimestamp: BigInt, currentBlock: BigInt): TvlData {
    const vault = ERC4626.bind(this.poolAddress)
    const tryTotalAssets = vault.try_totalSupply()

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
