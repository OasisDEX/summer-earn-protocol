import { Address, ethereum } from '@graphprotocol/graph-ts'
import { Account, Vault } from '../../../generated/schema'
import { BigDecimalConstants } from '../../common/constants'
import {
  getOrCreateArksPostActionSnapshots,
  getOrCreateVault,
  getOrCreateVaultsPostActionSnapshots,
} from '../../common/initializers'
import { getAprForTimePeriod } from '../../common/utils'
import { VaultAndPositionDetails, VaultDetails } from '../../types'
import { getArkDetails } from '../../utils/ark'
import { getPositionDetails } from '../../utils/position'
import { getVaultDetails } from '../../utils/vault'
import { updateArk } from './ark'
import { updatePosition } from './position'

export function updateVault(vaultDetails: VaultDetails, block: ethereum.Block): void {
  const vault = getOrCreateVault(Address.fromString(vaultDetails.vaultId), block)
  let previousPricePerShare = vault.pricePerShare
  if (
    !previousPricePerShare ||
    (previousPricePerShare && previousPricePerShare.equals(BigDecimalConstants.ZERO))
  ) {
    previousPricePerShare = BigDecimalConstants.ONE
  }
  const deltaTime = block.timestamp.minus(vault.lastUpdateTimestamp).toBigDecimal()
  vault.inputTokenBalance = vaultDetails.inputTokenBalance
  vault.outputTokenSupply = vaultDetails.outputTokenSupply
  vault.totalValueLockedUSD = vaultDetails.totalValueLockedUSD
  vault.outputTokenPriceUSD = vaultDetails.outputTokenPriceUSD
  vault.pricePerShare = vaultDetails.pricePerShare
  vault.lastUpdateTimestamp = block.timestamp

  vault.calculatedApr = getAprForTimePeriod(
    previousPricePerShare,
    vaultDetails.pricePerShare,
    deltaTime,
  )

  vault.save()
}

export function getVaultAndPositionDetails(
  event: ethereum.Event,
  account: Account,
  block: ethereum.Block,
): VaultAndPositionDetails {
  const vaultDetails = getVaultDetails(event.address, block)
  const positionDetails = getPositionDetails(event, account, vaultDetails)
  return { vaultDetails: vaultDetails, positionDetails: positionDetails }
}

export function getAndUpdateVaultAndPositionDetails(
  event: ethereum.Event,
  account: Account,
  block: ethereum.Block,
): VaultAndPositionDetails {
  const result = getVaultAndPositionDetails(event, account, block)

  updateVault(result.vaultDetails, event.block)
  updatePosition(result.positionDetails, event.block)

  return { vaultDetails: result.vaultDetails, positionDetails: result.positionDetails }
}

export function updateVaultAndArks(event: ethereum.Event, vault: Vault): void {
  const vaultDetails = getVaultDetails(event.address, event.block)

  updateVault(vaultDetails, event.block)
  getOrCreateVaultsPostActionSnapshots(event.address, event.block)

  const arks = vault.arksArray
  for (let i = 0; i < arks.length; i++) {
    const arkDetails = getArkDetails(
      Address.fromString(vault.id),
      Address.fromString(arks[i]),
      event.block,
    )
    updateArk(arkDetails, event.block)
    getOrCreateArksPostActionSnapshots(
      Address.fromString(vault.id),
      Address.fromString(arks[i]),
      event.block,
    )
  }
}
