import { Address, BigInt } from '@graphprotocol/graph-ts'
import { IGauge } from '../../generated/EntryPoint/IGauge'
import { IGaugeHookReceiver } from '../../generated/EntryPoint/IGaugeHookReceiver'
import { ISilo } from '../../generated/EntryPoint/ISilo'
import { ISiloConfig } from '../../generated/EntryPoint/ISiloConfig'
import { BigDecimalConstants } from '../constants/common'
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
    const gauge = IGauge.bind(gaugeAddress)
    const programNames = gauge.getAllProgramsNames()
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
      const program = gauge.incentivesProgram(programName)
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
}
