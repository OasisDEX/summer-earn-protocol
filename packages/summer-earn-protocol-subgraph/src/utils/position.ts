import { Address, BigInt, ethereum } from '@graphprotocol/graph-ts'
import { Position, PositionRewards, Vault } from '../../generated/schema'
import { FleetCommanderRewardsManager as FleetCommanderRewardsManagerContract } from '../../generated/templates/FleetCommanderRewardsManagerTemplate/FleetCommanderRewardsManager'
import { FleetCommander as FleetCommanderContract } from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import { addresses } from '../common/addressProvider'
import * as constants from '../common/constants'
import { getOrCreatePositionRewards, getOrCreateToken } from '../common/initializers'
import * as utils from '../common/utils'
import { formatAmount } from '../common/utils'
import { PositionDetails, VaultDetails } from '../types'

export function getPositionDetails(
  vault: Vault,
  account: Address,
  vaultDetails: VaultDetails,
  block: ethereum.Block,
): PositionDetails {
  const vaultContract = FleetCommanderContract.bind(Address.fromString(vault.id))
  const rewardsManagerContract = FleetCommanderRewardsManagerContract.bind(
    vaultDetails.rewardsManager,
  )
  const positionId = utils.formatPositionId(account.toHexString(), vaultDetails.vaultId)

  const unstakedShares = utils.readValue<BigInt>(
    vaultContract.try_balanceOf(account),
    constants.BigIntConstants.ZERO,
  )
  const stakedShares = utils.readValue<BigInt>(
    rewardsManagerContract.try_balanceOf(account),
    constants.BigIntConstants.ZERO,
  )
  const unstakedInputToken = utils.isZeroBigInt(unstakedShares)
    ? constants.BigIntConstants.ZERO
    : utils.readValue<BigInt>(
        vaultContract.try_convertToAssets(unstakedShares),
        constants.BigIntConstants.ZERO,
      )
  const stakedInputToken = utils.isZeroBigInt(stakedShares)
    ? constants.BigIntConstants.ZERO
    : utils.readValue<BigInt>(
        vaultContract.try_convertToAssets(stakedShares),
        constants.BigIntConstants.ZERO,
      )
  const unstakedInputTokenNormalized = formatAmount(
    unstakedInputToken,
    BigInt.fromI32(vaultDetails.inputToken.decimals),
  )
  const stakedInputTokenNormalized = formatAmount(
    stakedInputToken,
    BigInt.fromI32(vaultDetails.inputToken.decimals),
  )
  const totalInputTokenNormalized = unstakedInputTokenNormalized.plus(stakedInputTokenNormalized)
  // this shoul be accurate since all positions are updated on hourly basis as well as deposits withdrawals
  const priceInUSD = vaultDetails.inputTokenPriceUSD
  const unstakedInputTokenNormalizedUSD = unstakedInputTokenNormalized.times(priceInUSD)
  const stakedInputTokenNormalizedUSD = stakedInputTokenNormalized.times(priceInUSD)
  const totalInputTokenNormalizedUSD = totalInputTokenNormalized.times(priceInUSD)
  const position = Position.load(
    utils.formatPositionId(account.toHexString(), vaultDetails.vaultId),
  )

  const stakedInputTokenBalanceBeforeUpdate = position
    ? position.stakedInputTokenBalance
    : constants.BigIntConstants.ZERO
  const unstakedInputTokenBalanceBeforeUpdate = position
    ? position.unstakedInputTokenBalance
    : constants.BigIntConstants.ZERO
  const totalInputTokenBeforeUpdate = stakedInputTokenBalanceBeforeUpdate.plus(
    unstakedInputTokenBalanceBeforeUpdate,
  )

  const stakedInputTokenBalanceAfterUpdate = stakedInputToken
  const unstakedInputTokenBalanceAfterUpdate = unstakedInputToken
  const totalInputTokenAfterUpdate = stakedInputTokenBalanceAfterUpdate.plus(
    unstakedInputTokenBalanceAfterUpdate,
  )

  const stakedInputTokenDelta = stakedInputTokenBalanceAfterUpdate.minus(
    stakedInputTokenBalanceBeforeUpdate,
  )
  const unstakedInputTokenDelta = unstakedInputTokenBalanceAfterUpdate.minus(
    unstakedInputTokenBalanceBeforeUpdate,
  )
  const totalInputTokenDelta = totalInputTokenAfterUpdate.minus(totalInputTokenBeforeUpdate)

  const stakedInputTokenDeltaNormalized = formatAmount(
    stakedInputTokenDelta,
    BigInt.fromI32(vaultDetails.inputToken.decimals),
  )

  const unstakedInputTokenDeltaNormalized = formatAmount(
    unstakedInputTokenDelta,
    BigInt.fromI32(vaultDetails.inputToken.decimals),
  )

  const totalInputTokenDeltaNormalized = formatAmount(
    totalInputTokenDelta,
    BigInt.fromI32(vaultDetails.inputToken.decimals),
  )

  const stakedInputTokenDeltaNormalizedUSD = stakedInputTokenDeltaNormalized.times(priceInUSD)
  const unstakedInputTokenDeltaNormalizedUSD = unstakedInputTokenDeltaNormalized.times(priceInUSD)
  const totalInputTokenDeltaNormalizedUSD = totalInputTokenDeltaNormalized.times(priceInUSD)

  const rewards: PositionRewards[] = []
  let claimableSummer = constants.BigIntConstants.ZERO
  let claimableSummerNormalized = constants.BigDecimalConstants.ZERO

  for (let i = 0; i < vault.rewardTokens.length; i++) {
    if (stakedInputTokenNormalized.gt(constants.BigDecimalConstants.ZERO)) {
      const rewardTokenAddress = Address.fromString(vault.rewardTokens[i])
      const rewardToken = getOrCreateToken(rewardTokenAddress)
      const claimable = utils.readValue<BigInt>(
        rewardsManagerContract.try_earned(account, rewardTokenAddress),
        constants.BigIntConstants.ZERO,
      )
      const claimableNormalized = formatAmount(claimable, BigInt.fromI32(rewardToken.decimals))
      const positionRewards = getOrCreatePositionRewards(positionId, rewardToken, block)

      positionRewards.claimable = claimable
      positionRewards.claimableNormalized = claimableNormalized
      rewards.push(positionRewards)

      // ------------------------------------------------------------
      // will be deprecated in the future
      if (rewardTokenAddress.equals(addresses.SUMMER_TOKEN)) {
        claimableSummer = positionRewards.claimable
        claimableSummerNormalized = positionRewards.claimableNormalized
      }
      // ------------------------------------------------------------}
    }
  }

  return new PositionDetails(
    positionId,
    unstakedShares.plus(stakedShares), // outputTokenBalance
    stakedShares, // stakedOutputTokenBalance
    unstakedShares, // unstakedOutputTokenBalance
    totalInputTokenAfterUpdate, // inputTokenBalance
    totalInputTokenNormalized, // inputTokenBalanceNormalized
    totalInputTokenNormalizedUSD, // inputTokenBalanceNormalizedUSD
    stakedInputToken, // stakedInputTokenBalance
    stakedInputTokenNormalized, // stakedInputTokenBalanceNormalized
    stakedInputTokenNormalizedUSD, // stakedInputTokenBalanceNormalizedUSD
    unstakedInputToken, // unstakedInputTokenBalance
    unstakedInputTokenNormalized, // unstakedInputTokenBalanceNormalized
    unstakedInputTokenNormalizedUSD, // unstakedInputTokenBalanceNormalizedUSD
    unstakedInputTokenDelta, // unstakedInputTokenDelta
    unstakedInputTokenDeltaNormalized, // unstakedInputTokenDeltaNormalized
    unstakedInputTokenDeltaNormalizedUSD, // unstakedInputTokenDeltaNormalizedUSD
    stakedInputTokenDelta, // stakedInputTokenDelta
    stakedInputTokenDeltaNormalized, // stakedInputTokenDeltaNormalized
    stakedInputTokenDeltaNormalizedUSD, // stakedInputTokenDeltaNormalizedUSD
    totalInputTokenDelta, // inputTokenDelta
    totalInputTokenDeltaNormalized, // inputTokenDeltaNormalized
    totalInputTokenDeltaNormalizedUSD, // inputTokenDeltaNormalizedUSD
    claimableSummer, // claimableSummerToken
    claimableSummerNormalized, // claimableSummerTokenNormalized
    rewards, // rewards
    vaultDetails.vaultId, // vault
    account.toHexString(), // account
    vaultDetails.inputToken, // inputToken
    vaultDetails.protocol, // protocol
    vaultDetails.inputTokenPriceUSD, // inputTokenPriceUSD
  )
}
