import { Address, BigInt, ethereum } from '@graphprotocol/graph-ts'
import { Account } from '../../generated/schema'
import { FleetCommanderRewardsManager as FleetCommanderRewardsManagerContract } from '../../generated/templates/FleetCommanderRewardsManagerTemplate/FleetCommanderRewardsManager'
import { FleetCommander as FleetCommanderContract } from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import * as constants from '../common/constants'
import { getOrCreatePosition } from '../common/initializers'
import * as utils from '../common/utils'
import { formatAmount } from '../common/utils'
import { PositionDetails, VaultDetails } from '../types'

export function getPositionDetails(
  vault: Address,
  account: Account,
  vaultDetails: VaultDetails,
  block: ethereum.Block,
): PositionDetails {
  const vaultContract = FleetCommanderContract.bind(vault)
  const rewardsManagerContract = FleetCommanderRewardsManagerContract.bind(
    vaultDetails.rewardsManager,
  )
  const shares = utils.readValue<BigInt>(
    vaultContract.try_balanceOf(Address.fromString(account.id)),
    constants.BigIntConstants.ZERO,
  )
  const stakedShares = utils.readValue<BigInt>(
    rewardsManagerContract.try_balanceOf(Address.fromString(account.id)),
    constants.BigIntConstants.ZERO,
  )
  const inputToken = utils.readValue<BigInt>(
    vaultContract.try_convertToAssets(shares),
    constants.BigIntConstants.ZERO,
  )
  const stakedInputToken = utils.readValue<BigInt>(
    vaultContract.try_convertToAssets(stakedShares),
    constants.BigIntConstants.ZERO,
  )
  const inputTokenNormalized = formatAmount(
    inputToken,
    BigInt.fromI32(vaultDetails.inputToken.decimals),
  )
  const stakedInputTokenNormalized = formatAmount(
    stakedInputToken,
    BigInt.fromI32(vaultDetails.inputToken.decimals),
  )

  // this shoul be accurate since all positions are updated on hourly basis as well as deposits withdrawals
  const priceInUSD = vaultDetails.inputTokenPriceUSD
  const inputTokenNormalizedUSD = inputTokenNormalized.times(priceInUSD)
  const stakedInputTokenNormalizedUSD = stakedInputTokenNormalized.times(priceInUSD)
  const position = getOrCreatePosition(
    utils.formatPositionId(account.id, vaultDetails.vaultId),
    block,
  )
  const totalInputTokenBeforeUpdate = position.inputTokenBalance.plus(
    position.stakedInputTokenBalance,
  )
  const totalInputTokenAfterUpdate = inputToken.plus(stakedInputToken)
  const totalInputTokenDelta = totalInputTokenAfterUpdate.minus(totalInputTokenBeforeUpdate)
  const totalInputTokenDeltaNormalized = formatAmount(
    totalInputTokenDelta,
    BigInt.fromI32(vaultDetails.inputToken.decimals),
  )
  const totalInputTokenDeltaNormalizedUSD = totalInputTokenDeltaNormalized.times(priceInUSD)

  const stakedInputTokenDelta = stakedInputToken.minus(inputToken)
  const stakedInputTokenDeltaNormalized = formatAmount(
    stakedInputTokenDelta,
    BigInt.fromI32(vaultDetails.inputToken.decimals),
  )
  const stakedInputTokenDeltaNormalizedUSD = stakedInputTokenDeltaNormalized.times(priceInUSD)

  const inputTokenDelta = inputToken.minus(position.inputTokenBalance)
  const inputTokenDeltaNormalized = formatAmount(
    inputTokenDelta,
    BigInt.fromI32(vaultDetails.inputToken.decimals),
  )
  const inputTokenDeltaNormalizedUSD = inputTokenDeltaNormalized.times(priceInUSD)

  return new PositionDetails(
    utils.formatPositionId(account.id, vaultDetails.vaultId),
    shares,
    stakedShares,
    inputToken,
    inputTokenNormalized,
    inputTokenNormalizedUSD,
    stakedInputToken,
    stakedInputTokenNormalized,
    stakedInputTokenNormalizedUSD,
    inputTokenDelta,
    inputTokenDeltaNormalized,
    inputTokenDeltaNormalizedUSD,
    stakedInputTokenDelta,
    stakedInputTokenDeltaNormalized,
    stakedInputTokenDeltaNormalizedUSD,
    totalInputTokenDelta,
    totalInputTokenDeltaNormalized,
    totalInputTokenDeltaNormalizedUSD,
    vaultDetails.vaultId,
    account.id,
    vaultDetails.inputToken,
    vaultDetails.protocol,
  )
}
