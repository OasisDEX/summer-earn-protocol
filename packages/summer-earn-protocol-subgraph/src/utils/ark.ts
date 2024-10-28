import { Address, BigInt, ethereum } from '@graphprotocol/graph-ts'
import { Token } from '../../generated/schema'
import { Ark as ArkContract } from '../../generated/templates/FleetCommanderTemplate/Ark'
import * as constants from '../common/constants'
import { getOrCreateArk } from '../common/initializers'
import { getTokenPriceInUSD } from '../common/priceHelpers'
import * as utils from '../common/utils'
import { ArkDetails } from '../types'

export function getArkDetails(
  vaultAddress: Address,
  arkAddress: Address,
  block: ethereum.Block,
): ArkDetails {
  const ark = getOrCreateArk(vaultAddress, arkAddress, block)
  const arkContract = ArkContract.bind(arkAddress)
  const totalAssets = utils.readValue<BigInt>(
    arkContract.try_totalAssets(),
    constants.BigIntConstants.ZERO,
  )
  const inputToken = Token.load(ark.inputToken)!
  const inputTokenPriceUSD = getTokenPriceInUSD(Address.fromString(ark.inputToken), block)
  const arkDetails = new ArkDetails(
    ark.id,
    vaultAddress.toHexString(),
    totalAssets,
    utils
      .formatAmount(totalAssets, BigInt.fromI32(inputToken.decimals))
      .times(inputTokenPriceUSD.price),
  )

  return arkDetails
}
