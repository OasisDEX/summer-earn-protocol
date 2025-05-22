import { Address, BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { Comet } from '../../generated/EntryPoint/Comet'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { Product } from '../models/Product'
import { TvlData } from '../models/TvlData'
import { formatAmount } from '../utils/formatters'
import { getTokenPriceInUSD } from '../utils/price-helper'
import { RewardRate } from './BaseVaultProduct'

export class CompoundProduct extends Product {
  getRate(currentTimestamp: BigInt, currentBlock: BigInt): BigDecimal {
    if (currentBlock.lt(this.startBlock)) {
      return BigDecimalConstants.ZERO
    }
    const comet = Comet.bind(this.poolAddress)

    const tryUtilization = comet.try_getUtilization()
    if (tryUtilization.reverted) {
      return BigDecimalConstants.ZERO
    }
    const utilization = tryUtilization.value
    const trySupplyRate = comet.try_getSupplyRate(utilization)
    if (trySupplyRate.reverted) {
      return BigDecimalConstants.ZERO
    }
    return trySupplyRate.value
      .toBigDecimal()
      .times(BigDecimalConstants.SECONDS_PER_YEAR.times(BigDecimalConstants.HUNDRED))
      .div(BigDecimalConstants.WAD)
  }

  getRewardsRates(currentTimestamp: BigInt, currentBlock: BigInt): RewardRate[] {
    return []
  }

  getTvl(currentTimestamp: BigInt, currentBlock: BigInt): TvlData {
    const comet = Comet.bind(this.poolAddress)

    const tryTotalAssets = comet.try_totalSupply()

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
