import { Address, BigDecimal, ethereum } from '@graphprotocol/graph-ts'
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
  if (
    deltaTime.gt(BigDecimalConstants.ZERO) &&
    !previousPricePerShare.equals(vaultDetails.pricePerShare)
  ) {
    vault.calculatedApr = getAprForTimePeriod(
      previousPricePerShare,
      vaultDetails.pricePerShare,
      deltaTime,
    )
  }
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

export function updateVaultAPRs(vault: Vault): void {
  const MAX_APR_VALUES = 365
  const currentApr = vault.calculatedApr
  let aprValues = vault.aprValues

  // Remove oldest value if we've reached max capacity
  if (aprValues.length >= MAX_APR_VALUES) {
    aprValues.shift()
  }

  // Add new APR value
  aprValues.push(currentApr)

  // Update vault's APR array
  vault.aprValues = aprValues

  // Calculate averages for different time windows
  const length = aprValues.length
  let sum7d = BigDecimalConstants.ZERO
  let sum30d = BigDecimalConstants.ZERO
  let sum90d = BigDecimalConstants.ZERO
  let sum180d = BigDecimalConstants.ZERO
  let sum365d = BigDecimalConstants.ZERO

  for (let i = 0; i < length; i++) {
    const value = aprValues[length - 1 - i] // Start from the most recent

    if (i < 7) sum7d = sum7d.plus(value)
    if (i < 30) sum30d = sum30d.plus(value)
    if (i < 90) sum90d = sum90d.plus(value)
    if (i < 180) sum180d = sum180d.plus(value)
    if (i < 365) sum365d = sum365d.plus(value)
  }

  // Update rolling averages
  vault.apr7d = calculateAverageAPR(sum7d, 7, length)
  vault.apr30d = calculateAverageAPR(sum30d, 30, length)
  vault.apr90d = calculateAverageAPR(sum90d, 90, length)
  vault.apr180d = calculateAverageAPR(sum180d, 180, length)
  vault.apr365d = calculateAverageAPR(sum365d, 365, length)
}

function calculateAverageAPR(sum: BigDecimal, period: i32, length: i32): BigDecimal {
  const periodBD = BigDecimal.fromString(period.toString())
  const lengthBD = BigDecimal.fromString(length.toString())
  return length >= period ? sum.div(periodBD) : sum.div(lengthBD)
}
