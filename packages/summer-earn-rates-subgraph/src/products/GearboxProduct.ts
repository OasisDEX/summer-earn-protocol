import { Address, BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { GearboxPool } from '../../generated/EntryPoint/GearboxPool'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { Product } from '../models/Product'
import { TvlData } from '../models/TvlData'
import { formatAmount } from '../utils/formatters'
import { getTokenPriceInUSD } from '../utils/price-helper'
import { RewardRate } from './BaseVaultProduct'

export class GearboxProduct extends Product {
  getRate(currentTimestamp: BigInt, currentBlock: BigInt): BigDecimal {
    if (currentBlock.lt(this.startBlock)) {
      return BigDecimalConstants.ZERO
    }
    const pool = GearboxPool.bind(this.poolAddress)
    const tryRate = pool.try_supplyRate()
    if (tryRate.reverted) {
      return BigDecimalConstants.ZERO
    }
    return tryRate.value
      .toBigDecimal()
      .times(BigDecimalConstants.HUNDRED)
      .div(BigDecimalConstants.RAY)
  }
  getRewardsRates(currentTimestamp: BigInt, currentBlock: BigInt): RewardRate[] {
    return []
  }

  getTvl(currentTimestamp: BigInt, currentBlock: BigInt): TvlData {
    const pool = GearboxPool.bind(this.poolAddress)
    const tryTotalAssets = pool.try_totalAssets()

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
