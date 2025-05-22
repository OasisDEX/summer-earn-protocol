import { Address, BigInt } from '@graphprotocol/graph-ts'
import { ISiloIncentivesController } from '../../generated/EntryPoint/ISiloIncentivesController'
import { ISiloVault } from '../../generated/EntryPoint/ISiloVault'
import { ISiloVaultIncentivesModule } from '../../generated/EntryPoint/ISiloVaultIncentivesModule'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { TvlData } from '../models/TvlData'
import { formatAmount } from '../utils/formatters'
import { getOrCreateToken } from '../utils/initializers'
import { aprToApy } from '../utils/math'
import { getTokenPriceInUSD } from '../utils/price-helper'
import { RewardRate } from './BaseVaultProduct'
import { ERC4626Product } from './ERC4626Product'

export class SiloVaultProduct extends ERC4626Product {
  getRewardsRates(blockTimestamp: BigInt, blockNumber: BigInt): RewardRate[] {
    const siloVaultAddress = this.poolAddress
    const vault = ISiloVault.bind(siloVaultAddress)
    const incentivesModule = ISiloVaultIncentivesModule.bind(vault.INCENTIVES_MODULE())
    const incentivesControllers = incentivesModule.getNotificationReceivers()

    const vaultAsset = getOrCreateToken(vault.asset())
    const vaultAssetPriceInUSD = getTokenPriceInUSD(
      Address.fromBytes(vaultAsset.address),
      blockNumber,
    )
    const totalAssets = vault.totalAssets()
    const totalAssetsNormalized = formatAmount(totalAssets, vaultAsset.decimals)
    const totalAssetsNormalizedInUSD = totalAssetsNormalized.times(vaultAssetPriceInUSD.price)
    const rewardsRates = new Array<RewardRate>()
    for (let i = 0; i < incentivesControllers.length; i++) {
      const incentivesController = ISiloIncentivesController.bind(incentivesControllers[i])
      const programNames = incentivesController.getAllProgramsNames()

      for (let j = 0; j < programNames.length; j++) {
        const programName = programNames[j]
        const maybeProgram = incentivesController.try_incentivesProgram(programName)
        if (maybeProgram.reverted) {
          continue
        }
        const program = maybeProgram.value
        const rewardToken = getOrCreateToken(program.rewardToken)
        const emissionsPerSecond = program.emissionPerSecond
        const emissionsPerSecondNormalized = formatAmount(emissionsPerSecond, rewardToken.decimals)
        const rewardTokenPrice = getTokenPriceInUSD(
          Address.fromBytes(rewardToken.address),
          blockNumber,
        )
        const emissionsPerSecondInUSD = emissionsPerSecondNormalized.times(rewardTokenPrice.price)
        const emissionsPerYearInUSD = emissionsPerSecondInUSD.times(
          BigDecimalConstants.SECONDS_PER_YEAR,
        )
        const apr = emissionsPerYearInUSD
          .div(totalAssetsNormalizedInUSD)
          .times(BigDecimalConstants.HUNDRED)
        const rewardRate = new RewardRate(rewardToken, aprToApy(apr))
        if (apr.gt(BigDecimalConstants.ZERO)) {
          rewardsRates.push(rewardRate)
        }
      }
    }

    // deduplicate and aggregate rewards
    const uniqueRewards = new Map<string, RewardRate>()
    for (let i = 0; i < rewardsRates.length; i++) {
      const rewardRate = rewardsRates[i]
      const key = `${rewardRate.rewardToken.id.toHexString()}`
      if (!uniqueRewards.has(key)) {
        uniqueRewards.set(key, rewardRate)
      } else {
        const existingRate = uniqueRewards.get(key)
        existingRate.rate = existingRate.rate.plus(rewardRate.rate)
        uniqueRewards.set(key, existingRate)
      }
    }
    return uniqueRewards.values()
  }

  getTvl(currentTimestamp: BigInt, currentBlock: BigInt): TvlData {
    const vault = ISiloVault.bind(this.poolAddress)
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
