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
  const underlying = utils.readValue<BigInt>(
    vaultContract.try_convertToAssets(shares),
    constants.BigIntConstants.ZERO,
  )
  const stakedUnderlying = utils.readValue<BigInt>(
    vaultContract.try_convertToAssets(stakedShares),
    constants.BigIntConstants.ZERO,
  )
  const underlyingNormalized = formatAmount(
    underlying,
    BigInt.fromI32(vaultDetails.inputToken.decimals),
  )
  const stakedUnderlyingNormalized = formatAmount(
    stakedUnderlying,
    BigInt.fromI32(vaultDetails.inputToken.decimals),
  )
  const priceInUSD = vaultDetails.inputTokenPriceUSD
  const underlyingNormalizedUSD = underlyingNormalized.times(priceInUSD)
  const stakedUnderlyingNormalizedUSD = stakedUnderlyingNormalized.times(priceInUSD)
  const position = getOrCreatePosition(
    utils.formatPositionId(account.id, vaultDetails.vaultId),
    block,
  )
  const totalUnderlyingBeforeUpdate = position.inputTokenBalance.plus(
    position.stakedInputTokenBalance,
  )
  const totalUnderlyingAfterUpdate = underlying.plus(stakedUnderlying)
  const totalUnderlyingDelta = totalUnderlyingAfterUpdate.minus(totalUnderlyingBeforeUpdate)
  const totalUnderlyingDeltaNormalized = formatAmount(
    totalUnderlyingDelta,
    BigInt.fromI32(vaultDetails.inputToken.decimals),
  )
  const totalUnderlyingDeltaNormalizedUSD = totalUnderlyingDeltaNormalized.times(priceInUSD)

  return new PositionDetails(
    utils.formatPositionId(account.id, vaultDetails.vaultId),
    shares,
    stakedShares,
    underlying,
    underlyingNormalized,
    underlyingNormalizedUSD,
    stakedUnderlying,
    stakedUnderlyingNormalized,
    stakedUnderlyingNormalizedUSD,
    totalUnderlyingDelta,
    totalUnderlyingDeltaNormalized,
    totalUnderlyingDeltaNormalizedUSD,
    vaultDetails.vaultId,
    account.id,
    vaultDetails.inputToken,
    vaultDetails.protocol,
  )
}
