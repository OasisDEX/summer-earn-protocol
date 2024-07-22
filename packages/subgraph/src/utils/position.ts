import { Address, BigInt, ethereum } from '@graphprotocol/graph-ts'
import { Account } from '../../generated/schema'
import { FleetCommander as FleetCommanderContract } from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import * as constants from '../common/constants'
import * as utils from '../common/utils'
import { formatAmount } from '../common/utils'
import { PositionDetails, VaultDetails } from '../types'

export function getPositionDetails(
  event: ethereum.Event,
  account: Account,
  vaultDetails: VaultDetails,
): PositionDetails {
  const vaultContract = FleetCommanderContract.bind(event.address)
  const shares = utils.readValue<BigInt>(
    vaultContract.try_balanceOf(Address.fromString(account.id)),
    constants.BigIntConstants.ZERO,
  )
  const underlying = utils.readValue<BigInt>(
    vaultContract.try_convertToAssets(shares),
    constants.BigIntConstants.ZERO,
  )
  const underlyingNormalized = formatAmount(
    underlying,
    BigInt.fromI32(vaultDetails.inputToken.decimals),
  )
  const priceInUSD = vaultDetails.inputTokenPriceUSD
  const underlyingNormalizedUSD = underlyingNormalized.times(priceInUSD)

  return new PositionDetails(
    utils.formatPositionId(account.id, vaultDetails.vaultId),
    shares,
    underlying,
    underlyingNormalized,
    underlyingNormalizedUSD,
    vaultDetails.vaultId,
    account.id,
    vaultDetails.inputToken,
    vaultDetails.protocol,
  )
}
