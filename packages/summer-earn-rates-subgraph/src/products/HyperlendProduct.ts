import { Address, BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { AaveV3PoolDataProvider } from '../../generated/EntryPoint/AaveV3PoolDataProvider'
import { addresses } from '../constants/addresses'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { Product } from '../models/Product'
import { TvlData } from '../models/TvlData'
import { formatAmount } from '../utils/formatters'
import { getTokenPriceInUSD } from '../utils/price-helper'
import { RewardRate } from './BaseVaultProduct'

export class HyperlendProduct extends Product {
  getRate(currentTimestamp: BigInt, currentBlock: BigInt): BigDecimal {
    if (currentBlock.lt(this.startBlock)) {
      return BigDecimalConstants.ZERO
    }
    const pool = AaveV3PoolDataProvider.bind(addresses.HYPERLEND_DATA_PROVIDER)
    const tryReserveData = pool.try_getReserveData(Address.fromBytes(this.token.address))
    if (tryReserveData.reverted) {
      return BigDecimalConstants.ZERO
    }
    return tryReserveData.value
      .getLiquidityRate()
      .toBigDecimal()
      .times(BigDecimalConstants.HUNDRED)
      .div(BigDecimalConstants.RAY)
  }
  getRewardsRates(currentTimestamp: BigInt, currentBlock: BigInt): RewardRate[] {
    return []
  }

  getTvl(currentTimestamp: BigInt, currentBlock: BigInt): TvlData {
    const pool = AaveV3PoolDataProvider.bind(addresses.HYPERLEND_DATA_PROVIDER)
    const tryATokenTotalSupply = pool.try_getATokenTotalSupply(
      Address.fromBytes(this.token.address),
    )

    if (tryATokenTotalSupply.reverted) {
      return new TvlData(BigIntConstants.ZERO, BigDecimalConstants.ZERO, BigDecimalConstants.ZERO)
    }

    const tokenAmountRaw = tryATokenTotalSupply.value
    const tokenAmountNormalized = formatAmount(tokenAmountRaw, this.token.decimals)
    const tokenPriceInUsd = getTokenPriceInUSD(Address.fromBytes(this.token.address), currentBlock)
    const usdAmountNormalized = tokenAmountNormalized.times(tokenPriceInUsd.price)

    return new TvlData(tokenAmountRaw, tokenAmountNormalized, usdAmountNormalized)
  }
}
