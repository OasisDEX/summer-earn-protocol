import { Address, ethereum } from '@graphprotocol/graph-ts'
import { BigDecimalConstants } from '../../common/constants'
import { getOrCreateVault } from '../../common/initializers'
import { getAprForTimePeriod } from '../../common/utils'
import { VaultDetails } from '../../types'

export function updateVault(vaultDetails: VaultDetails, block: ethereum.Block): void {
  const vault = getOrCreateVault(Address.fromString(vaultDetails.vaultId), block)
  const previousPricePerShare = vault.pricePerShare ? vault.pricePerShare : BigDecimalConstants.ZERO
  const deltaTime = block.timestamp.minus(vault.lastUpdateTimestamp).toBigDecimal()

  vault.inputTokenBalance = vaultDetails.inputTokenBalance
  vault.outputTokenSupply = vaultDetails.outputTokenSupply
  vault.totalValueLockedUSD = vaultDetails.totalValueLockedUSD
  vault.outputTokenPriceUSD = vaultDetails.outputTokenPriceUSD
  vault.pricePerShare = vaultDetails.pricePerShare
  vault.lastUpdateTimestamp = block.timestamp

  vault.apr = getAprForTimePeriod(previousPricePerShare!, vaultDetails.pricePerShare, deltaTime)

  vault.save()
}
