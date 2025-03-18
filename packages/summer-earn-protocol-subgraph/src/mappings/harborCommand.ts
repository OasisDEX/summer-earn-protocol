import { Address, BigInt, ethereum, log } from '@graphprotocol/graph-ts'
import { FleetCommanderEnlisted } from '../../generated/HarborCommand/HarborCommand'
import { Vault, YieldAggregator } from '../../generated/schema'
import { BigIntConstants } from '../common/constants'
import {
  getOrCreateArksDailySnapshots,
  getOrCreateArksHourlySnapshots,
  getOrCreatePositionDailySnapshot,
  getOrCreatePositionHourlySnapshot,
  getOrCreatePositionWeeklySnapshot,
  getOrCreateVault,
  getOrCreateVaultWeeklySnapshots,
  getOrCreateVaultsDailySnapshots,
  getOrCreateVaultsHourlySnapshots,
  getOrCreateYieldAggregator,
} from '../common/initializers'
import { getArkDetails } from '../utils/ark'
import { getVaultDetails } from '../utils/vault'
import {
  getDailyTimestamp,
  getHourlyTimestamp,
  getWeeklyOffsetTimestamp,
  handleVaultRate,
} from '../utils/vaultRateHandlers'
import { updateArk } from './entities/ark'
import { updateVault } from './entities/vault'

export function handleFleetCommanderEnlisted(event: FleetCommanderEnlisted): void {
  getOrCreateVault(event.params.fleetCommander, event.block)
}

function updateArkData(vault: Vault, arkAddress: Address, block: ethereum.Block): void {
  const arkDetails = getArkDetails(vault, arkAddress, block)
  updateArk(arkDetails, block, true)
}

export function updateVaultData(vault: Vault, block: ethereum.Block): Vault {
  const vaultDetails = getVaultDetails(vault, block)
  return updateVault(vaultDetails, block, true)
}

// Snapshot management functions
function updateArkSnapshots(
  vault: Vault,
  arkAddress: Address,
  block: ethereum.Block,
  shouldUpdateDaily: boolean,
): void {
  getOrCreateArksHourlySnapshots(vault, arkAddress, block)
  if (shouldUpdateDaily) {
    getOrCreateArksDailySnapshots(vault, arkAddress, block)
  }
}

function updateVaultSnapshots(
  vault: Vault,
  block: ethereum.Block,
  shouldUpdateDaily: boolean,
  shouldUpdateWeekly: boolean,
): void {
  handleVaultRate(block, vault.id)
  getOrCreateVaultsHourlySnapshots(vault, block)
  if (shouldUpdateDaily) {
    getOrCreateVaultsDailySnapshots(vault, block)
  }
  if (shouldUpdateWeekly) {
    getOrCreateVaultWeeklySnapshots(vault, block)
  }
}

// Main update orchestration functions
function processHourlyVaultUpdate(
  vaultAddress: Address,
  block: ethereum.Block,
  protocolLastDailyUpdateTimestamp: BigInt | null,
  protocolLastHourlyUpdateTimestamp: BigInt | null,
  protocolLastWeeklyUpdateTimestamp: BigInt | null,
): void {
  const dayPassed = hasDayPassed(protocolLastDailyUpdateTimestamp, block.timestamp)
  const hourPassed = hasHourPassed(protocolLastHourlyUpdateTimestamp, block.timestamp)
  const weekPassed = hasWeekPassed(protocolLastWeeklyUpdateTimestamp, block.timestamp)
  if (hourPassed) {
    let vault = getOrCreateVault(vaultAddress, block)
    const updatedVault = updateVaultData(vault, block)
    updateVaultSnapshots(updatedVault, block, dayPassed, weekPassed)

    // reload vault to get latest data
    vault = updatedVault
    if (!vault || !vault.id) {
      log.warning('Invalid vault at address ' + vaultAddress.toHexString(), [])
      return
    }

    const arks = vault.arksArray
    if (arks && arks.length > 0) {
      for (let j = 0; j < arks.length; j++) {
        if (!arks[j]) {
          log.warning('Empty ark ID at index ' + j.toString(), [])
          continue
        }

        if (!arks[j].startsWith('0x') || arks[j].length != 42) {
          log.warning('Invalid ark address format at index ' + j.toString(), [])
          continue
        }

        const arkAddress = Address.fromString(arks[j])
        updateArkData(vault, arkAddress, block)
        updateArkSnapshots(vault, arkAddress, block, dayPassed)
      }
    }

    const positions = vault.positions
    if (positions && positions.length > 0) {
      for (let k = 0; k < positions.length; k++) {
        const positionId = positions[k]
        if (!positionId) {
          log.warning('Empty position ID at index ' + k.toString(), [])
          continue
        }
        getOrCreatePositionHourlySnapshot(positionId, vault, block)
        if (dayPassed) {
          getOrCreatePositionDailySnapshot(positionId, vault, block)
        }
        if (weekPassed) {
          getOrCreatePositionWeeklySnapshot(positionId, vault, block)
        }
      }
    }
  }
}

export function handleInterval(block: ethereum.Block): void {
  if (!block || !block.timestamp) {
    log.warning('Invalid block or timestamp in handleInterval', [])
    return
  }

  let protocol = getOrCreateYieldAggregator(block.timestamp)

  if (!protocol || !protocol.vaultsArray) {
    log.warning('Protocol or vaultsArray is null', [])
    return
  }

  const vaults = protocol.vaultsArray

  for (let i = 0; i < vaults.length; i++) {
    if (!vaults[i]) {
      log.warning('Empty vault ID at index ' + i.toString(), [])
      continue
    }

    if (!vaults[i].startsWith('0x') || vaults[i].length != 42) {
      log.warning('Invalid vault address format at index ' + i.toString(), [])
      continue
    }

    const vaultAddress = Address.fromString(vaults[i])

    processHourlyVaultUpdate(
      vaultAddress,
      block,
      protocol.lastDailyUpdateTimestamp,
      protocol.lastHourlyUpdateTimestamp,
      protocol.lastWeeklyUpdateTimestamp,
    )
  }

  updateProtocolTimestamps(protocol, block)
  protocol.save()
}

function updateProtocolTimestamps(protocol: YieldAggregator, block: ethereum.Block): void {
  if (hasHourPassed(protocol.lastHourlyUpdateTimestamp, block.timestamp)) {
    const firstSecondOfThisHour = getHourlyTimestamp(block.timestamp)
    protocol.lastHourlyUpdateTimestamp = firstSecondOfThisHour

    if (hasDayPassed(protocol.lastDailyUpdateTimestamp, block.timestamp)) {
      const dayTimestamp = getDailyTimestamp(firstSecondOfThisHour)
      protocol.lastDailyUpdateTimestamp = dayTimestamp
    }

    if (hasWeekPassed(protocol.lastWeeklyUpdateTimestamp, block.timestamp)) {
      const weekTimestamp = getWeeklyOffsetTimestamp(firstSecondOfThisHour)
      protocol.lastWeeklyUpdateTimestamp = weekTimestamp
    }

    protocol.save()
  }
}

function hasDayPassed(lastUpdateTimestamp: BigInt | null, currentTimestamp: BigInt): boolean {
  if (!lastUpdateTimestamp || lastUpdateTimestamp.equals(BigIntConstants.ZERO)) {
    return true // Create initial snapshot if no previous timestamp or if it's zero
  }
  const currentDayTimestamp = getDailyTimestamp(currentTimestamp)
  const previousDayTimestamp = lastUpdateTimestamp
  return !currentDayTimestamp.equals(previousDayTimestamp)
}

function hasHourPassed(lastUpdateTimestamp: BigInt | null, currentTimestamp: BigInt): boolean {
  if (!lastUpdateTimestamp || lastUpdateTimestamp.equals(BigIntConstants.ZERO)) {
    return true // Create initial snapshot if no previous timestamp or if it's zero
  }
  const currentHourTimestamp = getHourlyTimestamp(currentTimestamp)
  const previousHourTimestamp = lastUpdateTimestamp
  return !currentHourTimestamp.equals(previousHourTimestamp)
}

function hasWeekPassed(lastUpdateTimestamp: BigInt | null, currentTimestamp: BigInt): boolean {
  if (!lastUpdateTimestamp || lastUpdateTimestamp.equals(BigIntConstants.ZERO)) {
    return true // Create initial snapshot if no previous timestamp or if it's zero
  }

  const currentWeekTimestamp = getWeeklyOffsetTimestamp(currentTimestamp)
  const previousWeekTimestamp = getWeeklyOffsetTimestamp(lastUpdateTimestamp)

  return !currentWeekTimestamp.equals(previousWeekTimestamp)
}
