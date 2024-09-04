import { Address, BigInt, ethereum } from '@graphprotocol/graph-ts'
import { FleetCommander as FleetCommanderContract } from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import * as constants from '../common/constants'
import { getOrCreateToken, getOrCreateVault } from '../common/initializers'
import { getTokenPriceInUSD } from '../common/priceHelpers'
import * as utils from '../common/utils'
import { formatAmount } from '../common/utils'
import { VaultDetails } from '../types'

export function getVaultDetails(vaultAddress: Address, block: ethereum.Block): VaultDetails {
  const vault = getOrCreateVault(vaultAddress, block)
  const vaultContract = FleetCommanderContract.bind(vaultAddress)
  const totalAssets = utils.readValue<BigInt>(
    vaultContract.try_totalAssets(),
    constants.BigIntConstants.ZERO,
  )
  const totalSupply = utils.readValue<BigInt>(
    vaultContract.try_totalSupply(),
    constants.BigIntConstants.ZERO,
  )

  const inputToken = getOrCreateToken(Address.fromString(vault.inputToken))
  const inputTokenPriceUSD = getTokenPriceInUSD(Address.fromString(vault.inputToken), block)
  const pricePerShare =
    totalSupply.toBigDecimal() == constants.BigDecimalConstants.ZERO
      ? constants.BigDecimalConstants.ONE
      : totalAssets.toBigDecimal().div(totalSupply.toBigDecimal())
  const outputTokenPriceUSD = pricePerShare.times(inputTokenPriceUSD.price)
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
