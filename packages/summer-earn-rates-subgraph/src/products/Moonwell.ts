import { Address, BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { IComptroller } from '../../generated/EntryPoint/IComptroller'
import { IMToken } from '../../generated/EntryPoint/IMToken'
import { IRewardDistributor } from '../../generated/EntryPoint/IRewardDistributor'
import { MoonwellToken } from '../../generated/EntryPoint/MoonwellToken'
import { BigDecimalConstants } from '../constants/common'
import { Product } from '../models/Product'
import { formatAmount } from '../utils/formatters'
import { getOrCreateToken } from '../utils/initializers'
import { getTokenPriceInUSD } from '../utils/price-helper'
import { RewardRate } from './BaseVaultProduct'
export class MoonwellProduct extends Product {
  getRate(currentTimestamp: BigInt, currentBlock: BigInt): BigDecimal {
    const vault = MoonwellToken.bind(this.poolAddress)
    const trySupplyRatePerTimestamp = vault.try_supplyRatePerTimestamp()

    if (trySupplyRatePerTimestamp.reverted) {
      return BigDecimal.zero()
    }

    const apr = trySupplyRatePerTimestamp.value
      .toBigDecimal()
      .times(BigDecimalConstants.SECONDS_PER_YEAR.times(BigDecimalConstants.HUNDRED))
      .div(BigDecimalConstants.WAD)

    return apr
  }
  getRewardsRates(currentTimestamp: BigInt, currentBlock: BigInt): RewardRate[] {
    const mToken = IMToken.bind(this.poolAddress)
    const comptroller = IComptroller.bind(mToken.comptroller())
    const rewardDistributor = IRewardDistributor.bind(comptroller.rewardDistributor())
    const asset = getOrCreateToken(mToken.underlying())
    const totalCash = mToken.getCash()
    const totalBorrows = mToken.totalBorrows()
    const totalReserves = mToken.totalReserves()
    const totalAssets = totalCash.plus(totalBorrows).minus(totalReserves)
    const totalAssetsNormalized = formatAmount(totalAssets, asset.decimals)
    const totalAssetsNormalizedInUSD = totalAssetsNormalized.times(
      getTokenPriceInUSD(Address.fromBytes(asset.address), currentBlock).price,
    )
    const marketConfigs = rewardDistributor.getAllMarketConfigs(this.poolAddress)
    const rewardsRates = new Array<RewardRate>()
    for (let i = 0; i < marketConfigs.length; i++) {
      if (marketConfigs[i].endTime < currentTimestamp) {
        continue
      }
      const marketConfig = marketConfigs[i]
      const rewardToken = getOrCreateToken(marketConfig.emissionToken)
      const emissionsPerSecond = marketConfig.supplyEmissionsPerSec
      const emissionsPerSecondNormalized = formatAmount(emissionsPerSecond, rewardToken.decimals)
      const rewardTokenPrice = getTokenPriceInUSD(
        Address.fromBytes(rewardToken.address),
        currentBlock,
      )
      const emissionsPerSecondInUSD = emissionsPerSecondNormalized.times(rewardTokenPrice.price)
      const emissionsPerYearInUSD = emissionsPerSecondInUSD.times(
        BigDecimalConstants.SECONDS_PER_YEAR,
      )
      const apr = emissionsPerYearInUSD
        .div(totalAssetsNormalizedInUSD)
        .times(BigDecimalConstants.HUNDRED)
      const rewardRate = new RewardRate(rewardToken, apr)
      if (apr.gt(BigDecimalConstants.ZERO)) {
        rewardsRates.push(rewardRate)
      }
    }
    return rewardsRates
  }
}
