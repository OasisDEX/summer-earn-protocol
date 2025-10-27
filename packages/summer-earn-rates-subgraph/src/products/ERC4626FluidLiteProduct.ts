import { Address, BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { ERC4626FluidLite } from '../../generated/EntryPoint/ERC4626FluidLite'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { TvlData } from '../models/TvlData'
import { formatAmount } from '../utils/formatters'
import { getTokenPriceInUSD } from '../utils/price-helper'
import { BaseVaultProduct } from './BaseVaultProduct'

export class ERC4626FluidLiteProduct extends BaseVaultProduct {
  getSharePrice(): BigDecimal {
    const vault = ERC4626FluidLite.bind(this.poolAddress)
    const netAssets = vault.try_getNetAssets()
    if (netAssets.reverted) {
      return BigDecimalConstants.ZERO
    }
    const netAssetsValue = netAssets.value.getNetAssets_()
    const totalSupply = vault.try_totalSupply()

    if (totalSupply.reverted) {
      return BigDecimalConstants.ZERO
    }

    const totalSupplyValue = totalSupply.value

    if (totalSupplyValue.equals(BigIntConstants.ZERO)) {
      return BigDecimalConstants.ZERO
    }

    return netAssetsValue.toBigDecimal().div(totalSupplyValue.toBigDecimal())
  }

  getTvl(currentTimestamp: BigInt, currentBlock: BigInt): TvlData {
    const vault = ERC4626FluidLite.bind(this.poolAddress)
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
