import { Address, BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { ERC4626 } from '../../generated/EntryPoint/ERC4626'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { TvlData } from '../models/TvlData'
import { formatAmount } from '../utils/formatters'
import { getTokenPriceInUSD } from '../utils/price-helper'
import { BaseVaultProduct } from './BaseVaultProduct'

export class ERC4626Product extends BaseVaultProduct {
  getSharePrice(): BigDecimal {
    const vault = ERC4626.bind(this.poolAddress)
    const tryTotalAssets = vault.try_totalAssets()
    const tryTotalSupply = vault.try_totalSupply()

    if (tryTotalAssets.reverted || tryTotalSupply.reverted) {
      return BigDecimalConstants.ZERO
    }

    const totalAssets = tryTotalAssets.value
    const totalSupply = tryTotalSupply.value

    if (totalSupply.equals(BigIntConstants.ZERO)) {
      return BigDecimalConstants.ZERO
    }

    return totalAssets.toBigDecimal().div(totalSupply.toBigDecimal())
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
