import { Address, BigDecimal, ethereum } from '@graphprotocol/graph-ts'
import { Vault } from '../../../generated/schema'
import { FleetCommanderRewardsManager as FleetCommanderRewardsManagerContract } from '../../../generated/templates/FleetCommanderRewardsManagerTemplate/FleetCommanderRewardsManager'
import { BigDecimalConstants, BigIntConstants } from '../../common/constants'
import {
  getOrCreateArksPostActionSnapshots,
  getOrCreateRewardToken,
  getOrCreateVault,
  getOrCreateVaultsPostActionSnapshots,
} from '../../common/initializers'
import { getAprForTimePeriod, updateProtocolTotalValueLockedUSD } from '../../common/utils'
import { VaultDetails } from '../../types'
import { getArkDetails } from '../../utils/ark'
import { getVaultDetails } from '../../utils/vault'
import { updateArk } from './ark'

export function updateVault(
  vaultDetails: VaultDetails,
  block: ethereum.Block,
  shouldUpdateApr: boolean,
): void {
  const vault = getOrCreateVault(Address.fromString(vaultDetails.vaultId), block)
  const deltaTime = block.timestamp.minus(vault.lastUpdateTimestamp).toBigDecimal()

  if (shouldUpdateApr) {
    const previousLastUpdatePricePerShare = vault.lastUpdatePricePerShare
    vault.lastUpdateTimestamp = block.timestamp
    vault.lastUpdatePricePerShare = vaultDetails.pricePerShare
    if (!previousLastUpdatePricePerShare.equals(BigDecimalConstants.ZERO)) {
      const pricePerShareDiff = vaultDetails.pricePerShare
        .minus(previousLastUpdatePricePerShare)
        .div(previousLastUpdatePricePerShare)
      if (
        deltaTime.gt(BigDecimalConstants.ZERO) &&
        !pricePerShareDiff.equals(BigDecimalConstants.ZERO) &&
        pricePerShareDiff.lt(BigDecimalConstants.TEN_BPS) &&
        vault.lastUpdatePricePerShare.gt(previousLastUpdatePricePerShare)
      ) {
        const baseApr = getAprForTimePeriod(
          previousLastUpdatePricePerShare,
          vaultDetails.pricePerShare,
          deltaTime,
        )
        const fee = vault.tipRate.toBigDecimal().div(BigDecimalConstants.WAD)
        vault.calculatedApr = fee.plus(baseApr)
      }
    }
  }
  vault.inputTokenBalance = vaultDetails.inputTokenBalance
  vault.outputTokenSupply = vaultDetails.outputTokenSupply
  vault.totalValueLockedUSD = vaultDetails.totalValueLockedUSD
  vault.outputTokenPriceUSD = vaultDetails.outputTokenPriceUSD
  vault.inputTokenPriceUSD = vaultDetails.inputTokenPriceUSD
  vault.pricePerShare = vaultDetails.pricePerShare
  vault.withdrawableTotalAssets = vaultDetails.withdrawableTotalAssets
  vault.withdrawableTotalAssetsUSD = vaultDetails.withdrawableTotalAssetsUSD
  vault.rewardTokenEmissionsAmountsPerOutputToken =
    vaultDetails.rewardTokenEmissionsAmountsPerOutputToken
  vault.save()
  updateProtocolTotalValueLockedUSD()
}

export function updateVaultAndArks(event: ethereum.Event, vaultId: string): void {
  const vaultAddress = Address.fromString(vaultId)
  const vaultDetails = getVaultDetails(vaultAddress, event.block)

  updateVault(vaultDetails, event.block, false)
  getOrCreateVaultsPostActionSnapshots(event.address, event.block)

  const arks = vaultDetails.arks
  for (let i = 0; i < arks.length; i++) {
    const arkDetails = getArkDetails(vaultAddress, arks[i], event.block)
    updateArk(arkDetails, event.block, false)
    getOrCreateArksPostActionSnapshots(vaultAddress, arks[i], event.block)
  }
}

export function updateVaultAPRs(vault: Vault, currentApr: BigDecimal): void {
  const MAX_APR_VALUES = 365
  let aprValues = vault.aprValues

  // Remove oldest value if we've reached max capacity
  if (aprValues.length >= MAX_APR_VALUES) {
    aprValues.shift()
  }

  // Add new APR value
  aprValues.push(currentApr)

  // Update vault's APR array
  vault.aprValues = aprValues

  // Calculate averages for different time windows
  const length = aprValues.length
  let sum7d = BigDecimalConstants.ZERO
  let sum30d = BigDecimalConstants.ZERO
  let sum90d = BigDecimalConstants.ZERO
  let sum180d = BigDecimalConstants.ZERO
  let sum365d = BigDecimalConstants.ZERO

  for (let i = 0; i < length; i++) {
    const value = aprValues[length - 1 - i] // Start from the most recent

    if (i < 7) sum7d = sum7d.plus(value)
    if (i < 30) sum30d = sum30d.plus(value)
    if (i < 90) sum90d = sum90d.plus(value)
    if (i < 180) sum180d = sum180d.plus(value)
    if (i < 365) sum365d = sum365d.plus(value)
  }

  // Update rolling averages
  vault.apr7d = calculateAverageAPR(sum7d, 7, length)
  vault.apr30d = calculateAverageAPR(sum30d, 30, length)
  vault.apr90d = calculateAverageAPR(sum90d, 90, length)
  vault.apr180d = calculateAverageAPR(sum180d, 180, length)
  vault.apr365d = calculateAverageAPR(sum365d, 365, length)
}

function calculateAverageAPR(sum: BigDecimal, period: i32, length: i32): BigDecimal {
  const periodBD = BigDecimal.fromString(period.toString())
  const lengthBD = BigDecimal.fromString(length.toString())
  return length >= period ? sum.div(periodBD) : sum.div(lengthBD)
}

export function addOrUpdateVaultRewardRates(
  vault: Vault,
  rewardsManagerAddress: Address,
  rewardToken: Address,
): void {
  const rewardsManagerContract = FleetCommanderRewardsManagerContract.bind(rewardsManagerAddress)
  const rewardsData = rewardsManagerContract.rewardData(rewardToken)
  const rewardTokens = vault.rewardTokens
  const index = rewardTokens.indexOf(rewardToken.toHexString())

  if (index !== -1) {
    const rewardTokenEmissionsAmounts = vault.rewardTokenEmissionsAmount
    rewardTokenEmissionsAmounts[index] = rewardsData
      .getRewardRate()
      .times(BigIntConstants.SECONDS_PER_DAY)
    vault.rewardTokenEmissionsAmount = rewardTokenEmissionsAmounts

    const rewardTokenEmissionsAmountsPerOutputToken =
      vault.rewardTokenEmissionsAmountsPerOutputToken
    rewardTokenEmissionsAmountsPerOutputToken[index] = vault.outputTokenSupply.gt(
      BigIntConstants.ZERO,
    )
      ? rewardsData
          .getRewardRate()
          .times(BigIntConstants.SECONDS_PER_DAY)
          .div(vault.outputTokenSupply)
      : BigIntConstants.ZERO
    vault.rewardTokenEmissionsAmountsPerOutputToken = rewardTokenEmissionsAmountsPerOutputToken

    const rewardTokenEmissionsFinish = vault.rewardTokenEmissionsFinish
    rewardTokenEmissionsFinish[index] = rewardsData.getPeriodFinish()
    vault.rewardTokenEmissionsFinish = rewardTokenEmissionsFinish

    vault.save()
  } else {
    const rewardTokens = vault.rewardTokens
    const rewardTokenEntity = getOrCreateRewardToken(rewardToken)
    rewardTokens.push(rewardTokenEntity.id)
    vault.rewardTokens = rewardTokens

    const rewardTokenEmissionsAmounts = vault.rewardTokenEmissionsAmount
    rewardTokenEmissionsAmounts.push(
      rewardsData.getRewardRate().times(BigIntConstants.SECONDS_PER_DAY),
    )
    vault.rewardTokenEmissionsAmount = rewardTokenEmissionsAmounts

    const rewardTokenEmissionsAmountsPerOutputToken =
      vault.rewardTokenEmissionsAmountsPerOutputToken
    rewardTokenEmissionsAmountsPerOutputToken.push(
      vault.outputTokenSupply.gt(BigIntConstants.ZERO)
        ? rewardsData
            .getRewardRate()
            .times(BigIntConstants.SECONDS_PER_DAY)
            .div(vault.outputTokenSupply)
        : BigIntConstants.ZERO,
    )
    vault.rewardTokenEmissionsAmountsPerOutputToken = rewardTokenEmissionsAmountsPerOutputToken

    const rewardTokenEmissionsFinish = vault.rewardTokenEmissionsFinish
    rewardTokenEmissionsFinish.push(rewardsData.getPeriodFinish())
    vault.rewardTokenEmissionsFinish = rewardTokenEmissionsFinish

    vault.save()
  }
}

export function removeVaultRewardRates(vault: Vault, rewardToken: Address): void {
  const rewardTokens = vault.rewardTokens
  const index = rewardTokens.indexOf(rewardToken.toHexString())

  if (index !== -1) {
    const rewardTokenEmissionsAmounts = vault.rewardTokenEmissionsAmount
    const rewardTokenEmissionsAmountsPerOutputToken =
      vault.rewardTokenEmissionsAmountsPerOutputToken
    const rewardTokenEmissionsFinish = vault.rewardTokenEmissionsFinish

    rewardTokens.splice(index, 1)
    rewardTokenEmissionsAmounts.splice(index, 1)
    rewardTokenEmissionsAmountsPerOutputToken.splice(index, 1)
    rewardTokenEmissionsFinish.splice(index, 1)

    vault.rewardTokens = rewardTokens
    vault.rewardTokenEmissionsAmount = rewardTokenEmissionsAmounts
    vault.rewardTokenEmissionsAmountsPerOutputToken = rewardTokenEmissionsAmountsPerOutputToken
    vault.rewardTokenEmissionsFinish = rewardTokenEmissionsFinish

    vault.save()
  }
}
