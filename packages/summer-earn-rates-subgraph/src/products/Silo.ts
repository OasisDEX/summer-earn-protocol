import { Address, BigInt } from '@graphprotocol/graph-ts'
import { IGaugeHookReceiver } from '../../generated/EntryPoint/IGaugeHookReceiver'
import { ISilo } from '../../generated/EntryPoint/ISilo'
import { ISiloConfig } from '../../generated/EntryPoint/ISiloConfig'
import { ISiloIncentivesController } from '../../generated/EntryPoint/ISiloIncentivesController'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { TvlData } from '../models/TvlData'
import { formatAmount } from '../utils/formatters'
import { getOrCreateToken } from '../utils/initializers'
import { aprToApy } from '../utils/math'
import { getTokenPriceInUSD } from '../utils/price-helper'
import { RewardRate } from './BaseVaultProduct'
import { ERC4626Product } from './ERC4626Product'

export class SiloProduct extends ERC4626Product {
  getRewardsRates(blockTimestamp: BigInt, blockNumber: BigInt): RewardRate[] {
    const siloAddress = this.poolAddress
    const silo = ISilo.bind(siloAddress)
    const gaugeHookReceiver = ISiloConfig.bind(silo.config()).getConfig(siloAddress).hookReceiver
    const gaugeHook = IGaugeHookReceiver.bind(gaugeHookReceiver)
    const gaugeAddress = gaugeHook.configuredGauges(siloAddress)
    const incentivesController = ISiloIncentivesController.bind(gaugeAddress)
    const maybeProgramNames = incentivesController.try_getAllProgramsNames()
    if (maybeProgramNames.reverted) {
      return []
    }
    const programNames = maybeProgramNames.value
    const siloAsset = getOrCreateToken(silo.asset())
    const siloAssetPriceInUSD = getTokenPriceInUSD(
      Address.fromBytes(siloAsset.address),
      blockNumber,
    )
    const totalAssets = silo.totalAssets()
    const totalAssetsNormalized = formatAmount(totalAssets, siloAsset.decimals)
    const totalAssetsNormalizedInUSD = totalAssetsNormalized.times(siloAssetPriceInUSD.price)
    const rewardsRates = new Array<RewardRate>()

    for (let i = 0; i < programNames.length; i++) {
      const programName = programNames[i]
      const program = incentivesController.incentivesProgram(programName)
      // check if distribution end is in the past
      const distributionEnd = program.distributionEnd
      if (distributionEnd.lt(blockTimestamp)) {
        continue
      }

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
    return rewardsRates
  }

  getTvl(currentTimestamp: BigInt, currentBlock: BigInt): TvlData {
    const vault = ISilo.bind(this.poolAddress)
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
