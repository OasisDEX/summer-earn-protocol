import { Address, BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { ERC20 } from '../../generated/EntryPoint/ERC20'
import { IStakingRewards } from '../../generated/EntryPoint/IStakingRewards'
import { addresses } from '../constants/addresses'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { Product } from '../models/Product'
import { TvlData } from '../models/TvlData'
import { formatAmount } from '../utils/formatters'
import { getOrCreateToken } from '../utils/initializers'
import { getTokenPriceInUSD } from '../utils/price-helper'
import { RewardRate } from './BaseVaultProduct'
export class SkyRewardsProduct extends Product {
  getRate(currentTimestamp: BigInt, currentBlock: BigInt): BigDecimal {
    if (currentBlock.lt(this.startBlock)) {
      return BigDecimalConstants.ZERO
    }
    const stakingRewards = IStakingRewards.bind(this.poolAddress)
    const periodFinish = stakingRewards.try_periodFinish()
    if (periodFinish.reverted) {
      return BigDecimalConstants.ZERO
    }
    const periodFinishTimestamp = periodFinish.value
    if (currentTimestamp.gt(periodFinishTimestamp)) {
      return BigDecimalConstants.ZERO
    }
    const rewardRatePerSecond = stakingRewards.try_rewardRate()
    if (rewardRatePerSecond.reverted) {
      return BigDecimalConstants.ZERO
    }
    const rewardsTokenAddress = stakingRewards.try_rewardsToken()
    if (rewardsTokenAddress.reverted) {
      return BigDecimalConstants.ZERO
    }
    const rewardsToken = getOrCreateToken(rewardsTokenAddress.value)
    const stakedTokensAmount = ERC20.bind(addresses.USDS).balanceOf(this.poolAddress)
    const stakedTokensAmountNormalized = formatAmount(stakedTokensAmount, BigIntConstants.EIGHTEEN)
    const rewardRatePerYearNormalized = formatAmount(
      rewardRatePerSecond.value.times(BigIntConstants.YEAR_IN_SECONDS),
      rewardsToken.decimals,
    )
    const rewardTokenPrice = getTokenPriceInUSD(rewardsTokenAddress.value, currentBlock)
    const rewardRatePerYearNormalizedInUSD = rewardRatePerYearNormalized.times(
      rewardTokenPrice.price,
    )

    // we assume staked token is USDS
    return rewardRatePerYearNormalizedInUSD
      .times(BigDecimalConstants.HUNDRED)
      .div(stakedTokensAmountNormalized)
  }

  getRewardsRates(currentTimestamp: BigInt, currentBlock: BigInt): RewardRate[] {
    return []
  }

  getTvl(currentTimestamp: BigInt, currentBlock: BigInt): TvlData {
    const vault = IStakingRewards.bind(this.poolAddress)
    const tryTotalAssets = vault.try_totalSupply()
    const tryStakingToken = vault.try_stakingToken()

    if (tryTotalAssets.reverted || tryStakingToken.reverted) {
      return new TvlData(BigIntConstants.ZERO, BigDecimalConstants.ZERO, BigDecimalConstants.ZERO)
    }
    const stakingToken = getOrCreateToken(tryStakingToken.value)
    const tokenAmountRaw = tryTotalAssets.value
    const tokenAmountNormalized = formatAmount(tokenAmountRaw, stakingToken.decimals)
    const tokenPriceInUsd = getTokenPriceInUSD(
      Address.fromBytes(stakingToken.address),
      currentBlock,
    )
    const usdAmountNormalized = tokenAmountNormalized.times(tokenPriceInUsd.price)

    return new TvlData(tokenAmountRaw, tokenAmountNormalized, usdAmountNormalized)
  }
}
