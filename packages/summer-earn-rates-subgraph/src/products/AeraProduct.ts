import { Address, BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { AeraFeeCalculator } from '../../generated/EntryPoint/AeraFeeCalculator'
import { AeraVault } from '../../generated/EntryPoint/AeraVault'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { TvlData } from '../models/TvlData'
import { formatAmount } from '../utils/formatters'
import { getTokenPriceInUSD } from '../utils/price-helper'
import { BaseVaultProduct } from './BaseVaultProduct'

export class AeraProduct extends BaseVaultProduct {
  getSharePrice(): BigDecimal {
    const vault = AeraVault.bind(this.poolAddress)

    const feeCalculator = AeraFeeCalculator.bind(vault.feeCalculator())
    const tryUnitPrice = feeCalculator.try_convertUnitsToToken(
      this.poolAddress,
      Address.fromBytes(this.token.address),
      BigIntConstants.WAD,
    )
    if (tryUnitPrice.reverted) {
      return BigDecimalConstants.ZERO
    }
    const unitPrice = tryUnitPrice.value
    return formatAmount(unitPrice, this.token.decimals)
  }

  getTvl(currentTimestamp: BigInt, currentBlock: BigInt): TvlData {
    const vault = AeraVault.bind(this.poolAddress)
    const tryTotalAssetsSupply = vault.try_totalSupply()
    if (tryTotalAssetsSupply.reverted) {
      return new TvlData(BigIntConstants.ZERO, BigDecimalConstants.ZERO, BigDecimalConstants.ZERO)
    }
    const feeCalculator = AeraFeeCalculator.bind(vault.feeCalculator())
    const tryTotalSupply = feeCalculator.try_convertUnitsToToken(
      this.poolAddress,
      Address.fromBytes(this.token.address),
      tryTotalAssetsSupply.value,
    )
    if (tryTotalSupply.reverted) {
      return new TvlData(BigIntConstants.ZERO, BigDecimalConstants.ZERO, BigDecimalConstants.ZERO)
    }

    const tokenAmountRaw = tryTotalSupply.value
    const tokenAmountNormalized = formatAmount(tokenAmountRaw, this.token.decimals)
    const tokenPriceInUsd = getTokenPriceInUSD(Address.fromBytes(this.token.address), currentBlock)
    const usdAmountNormalized = tokenAmountNormalized.times(tokenPriceInUsd.price)

    return new TvlData(tokenAmountRaw, tokenAmountNormalized, usdAmountNormalized)
  }
}
