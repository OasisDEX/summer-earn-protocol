import { Address, ethereum, log } from '@graphprotocol/graph-ts'
import { getOrCreateVault } from '../../common/initializers'
import { VaultDetails } from '../../types'

export function updateVault(vaultDetails: VaultDetails, block: ethereum.Block): void {
  const vault = getOrCreateVault(Address.fromString(vaultDetails.vaultId), block)
  vault.inputTokenBalance = vaultDetails.inputTokenBalance
  vault.outputTokenSupply = vaultDetails.outputTokenSupply
  vault.totalValueLockedUSD = vaultDetails.totalValueLockedUSD
  vault.outputTokenPriceUSD = vaultDetails.outputTokenPriceUSD
  vault.pricePerShare = vaultDetails.pricePerShare
  log.error('vaultDetails.pricePerShare: {}', [vaultDetails.pricePerShare.toString()])
  log.error('vaultDetails.totalValueLockedUSD: {}', [vaultDetails.totalValueLockedUSD.toString()])
  log.error('vaultDetails.outputTokenPriceUSD: {}', [vaultDetails.outputTokenPriceUSD.toString()])
  log.error('vaultDetails.inputTokenBalance: {}', [vaultDetails.inputTokenBalance.toString()])
  log.error('vaultDetails.outputTokenSupply: {}', [vaultDetails.outputTokenSupply.toString()])
  vault.save()
}
