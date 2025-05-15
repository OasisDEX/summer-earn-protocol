import { Address, BigInt, ethereum, json, JSONValue, JSONValueKind } from '@graphprotocol/graph-ts'
import { Ark, Token, Vault } from '../../generated/schema'
import { Ark as ArkContract } from '../../generated/templates/FleetCommanderTemplate/Ark'
import * as constants from '../common/constants'
import { getOrCreateArk } from '../common/initializers'
import { getTokenPriceInUSD } from '../common/priceHelpers'
import * as utils from '../common/utils'
import { ArkDetails } from '../types'

export function getArkDetails(
  vault: Vault,
  arkAddress: Address,
  block: ethereum.Block,
): ArkDetails {
  const ark = getOrCreateArk(vault, arkAddress, block)
  const arkContract = ArkContract.bind(arkAddress)
  const totalAssets = utils.readValue<BigInt>(
    arkContract.try_totalAssets(),
    constants.BigIntConstants.ZERO,
  )
  const inputToken = Token.load(ark.inputToken)!
  const inputTokenPriceUSD = getTokenPriceInUSD(Address.fromString(ark.inputToken), block)
  const arkDetails = new ArkDetails(
    ark.id,
    vault.id,
    totalAssets,
    utils
      .formatAmount(totalAssets, BigInt.fromI32(inputToken.decimals))
      .times(inputTokenPriceUSD.price),
  )

  return arkDetails
}

export function getArkProductId(ark: Ark): string | null {
  if (!ark.details || ark.name == 'BufferArk') {
    return null
  }

  const details = ark.details!.toString()

  let jsonValue = json.fromString(details)
  const jsonData = jsonValue.toObject()

  if (!jsonData) {
    return null
  }

  if (!jsonData.isSet('pool') || !jsonData.isSet('protocol') || !jsonData.isSet('chainId')) {
    return null
  }

  const protocolValue = jsonData.get('protocol')
  const poolValue = jsonData.get('pool')
  const chainIdValue = jsonData.get('chainId')

  // Check if all values are strings
  if (!protocolValue || !poolValue || !chainIdValue) {
    return null
  }

  let protocol = decodeValue(protocolValue)
  const pool = decodeValue(poolValue)
  const chainId = decodeValue(chainIdValue)

  if (protocol === 'gearbox') {
    protocol = 'Gearbox'
  }
  if (protocol === 'fluid') {
    protocol = 'Fluid'
  }

  const assetAddress = ark.inputToken.toLowerCase()
  const poolAddress = pool.toLowerCase()
  const normalizedChainId = chainId.toLowerCase()

  return `${protocol}-${assetAddress}-${poolAddress}-${normalizedChainId}`
}

export function decodeValue(value: JSONValue): string {
  if (value.kind == JSONValueKind.STRING) {
    return value.toString()
  }
  if (value.kind == JSONValueKind.NUMBER) {
    return value.toBigInt().toString()
  }
  return ''
}
