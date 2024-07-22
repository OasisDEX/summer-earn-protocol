import { Address, BigInt, ethereum, log } from '@graphprotocol/graph-ts'
import { Vault } from '../../generated/schema'
import { FleetCommander as FleetCommanderContract } from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import * as constants from '../common/constants'
import { getOrCreateToken } from '../common/initializers'
import { getTokenPriceInUSD } from '../common/priceHelpers'
import * as utils from '../common/utils'
import { formatAmount } from '../common/utils'
import { VaultDetails } from '../types'

export function getVaultDetails(event: ethereum.Event, vault: Vault): VaultDetails {
  const vaultContract = FleetCommanderContract.bind(event.address)
  const totalAssets = utils.readValue<BigInt>(
    vaultContract.try_totalAssets(),
    constants.BigIntConstants.ZERO,
  )
  const totalSupply = utils.readValue<BigInt>(
    vaultContract.try_totalSupply(),
    constants.BigIntConstants.ZERO,
  )

  const inputToken = getOrCreateToken(Address.fromString(vault.inputToken))
  const inputTokenPriceUSD = getTokenPriceInUSD(
    Address.fromString(vault.inputToken),
    event.block.number,
  )
  const pricePerShare = totalAssets.toBigDecimal().div(totalSupply.toBigDecimal())
  const outputTokenPriceUSD = pricePerShare.times(inputTokenPriceUSD.price)
  log.error('outputTokenPriceUSD: {}', [outputTokenPriceUSD.toString()])
  log.error('inputTokenPriceUSD: {}', [inputTokenPriceUSD.price.toString()])
  log.error('pricePerShare: {}', [pricePerShare.toString()])
  log.error('totalAssets: {}', [totalAssets.toString()])
  log.error('totalSupply: {}', [totalSupply.toString()])
  return new VaultDetails(
    vault.id,
    formatAmount(totalAssets, BigInt.fromI32(inputToken.decimals)).times(inputTokenPriceUSD.price),
    pricePerShare,
    inputTokenPriceUSD.price,
    totalAssets,
    outputTokenPriceUSD,
    totalSupply,
    inputToken,
    vault.protocol,
  )
}
