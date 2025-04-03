import { Address, BigInt, ethereum } from '@graphprotocol/graph-ts'
import { Vault } from '../../generated/schema'
import { FleetCommanderRewardsManager as FleetCommanderRewardsManagerContract } from '../../generated/templates/FleetCommanderRewardsManagerTemplate/FleetCommanderRewardsManager'
import { FleetCommander as FleetCommanderContract } from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import * as constants from '../common/constants'
import { getOrCreatePosition } from '../common/initializers'
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
  const unstakedShares = utils.readValue<BigInt>(
    vaultContract.try_balanceOf(account),
    constants.BigIntConstants.ZERO,
  )
  const stakedShares = utils.readValue<BigInt>(
    rewardsManagerContract.try_balanceOf(account),
    constants.BigIntConstants.ZERO,
  )
  const unstakedInputToken = utils.readValue<BigInt>(
    vaultContract.try_convertToAssets(unstakedShares),
    constants.BigIntConstants.ZERO,
  )
  const stakedInputToken = utils.readValue<BigInt>(
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
  const position = getOrCreatePosition(
    utils.formatPositionId(account.toHexString(), vaultDetails.vaultId),
    block,
  )

  const stakedInputTokenBalanceBeforeUpdate = position.stakedInputTokenBalance
  const unstakedInputTokenBalanceBeforeUpdate = position.unstakedInputTokenBalance
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

  return new PositionDetails(
    utils.formatPositionId(account.toHexString(), vaultDetails.vaultId),
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
    vaultDetails.vaultId, // vault
    account.toHexString(), // account
    vaultDetails.inputToken, // inputToken
    vaultDetails.protocol, // protocol
  )
}
