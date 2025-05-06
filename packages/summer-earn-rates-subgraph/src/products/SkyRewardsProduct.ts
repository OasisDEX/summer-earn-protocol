import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { ERC20 } from '../../generated/EntryPoint/ERC20'
import { IStakingRewards } from '../../generated/EntryPoint/IStakingRewards'
import { addresses } from '../constants/addresses'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { Product } from '../models/Product'
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
    return rewardRatePerYearNormalizedInUSD.times(BigDecimalConstants.HUNDRED).div(stakedTokensAmountNormalized)
  }

  getRewardsRates(currentTimestamp: BigInt, currentBlock: BigInt): RewardRate[] {
    return []
  }
}
