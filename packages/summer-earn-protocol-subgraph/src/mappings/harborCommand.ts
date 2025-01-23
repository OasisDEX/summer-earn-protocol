import { Address, BigInt, ethereum } from '@graphprotocol/graph-ts'
import { FleetCommanderEnlisted } from '../../generated/HarborCommand/HarborCommand'
import { YieldAggregator } from '../../generated/schema'
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

function updateArkData(vaultAddress: Address, arkAddress: Address, block: ethereum.Block): void {
  const arkDetails = getArkDetails(vaultAddress, arkAddress, block)
  updateArk(arkDetails, block, true)
}

function updateVaultData(vaultAddress: Address, block: ethereum.Block): void {
  const vaultDetails = getVaultDetails(vaultAddress, block)
  updateVault(vaultDetails, block, true)
}

// Snapshot management functions
function updateArkSnapshots(
  vaultAddress: Address,
  arkAddress: Address,
  block: ethereum.Block,
  shouldUpdateDaily: boolean,
): void {
  getOrCreateArksHourlySnapshots(vaultAddress, arkAddress, block)
  if (shouldUpdateDaily) {
    getOrCreateArksDailySnapshots(vaultAddress, arkAddress, block)
  }
}

function updateVaultSnapshots(
  vaultAddress: Address,
  block: ethereum.Block,
  shouldUpdateDaily: boolean,
  shouldUpdateWeekly: boolean,
): void {
  handleVaultRate(block, vaultAddress.toHexString())
  getOrCreateVaultsHourlySnapshots(vaultAddress, block)
  if (shouldUpdateDaily) {
    getOrCreateVaultsDailySnapshots(vaultAddress, block)
  }
  if (shouldUpdateWeekly) {
    getOrCreateVaultWeeklySnapshots(vaultAddress, block)
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
    const vault = getOrCreateVault(vaultAddress, block)

    // Update main data
    updateVaultData(vaultAddress, block)
    updateVaultSnapshots(vaultAddress, block, dayPassed, weekPassed)

    // Update associated arks
    const arks = vault.arksArray
    for (let j = 0; j < arks.length; j++) {
      const arkAddress = Address.fromString(arks[j])
      updateArkData(vaultAddress, arkAddress, block)
      updateArkSnapshots(vaultAddress, arkAddress, block, dayPassed)
    }

    const positions = vault.positions // Assuming you have a way to get positions related to the vault
    for (let k = 0; k < positions.length; k++) {
      const positionId = positions[k]
      getOrCreatePositionHourlySnapshot(positionId, vaultAddress, block)
      if (dayPassed) {
        getOrCreatePositionDailySnapshot(positionId, vaultAddress, block)
      }
      if (weekPassed) {
        getOrCreatePositionWeeklySnapshot(positionId, vaultAddress, block)
      }
    }
  }
}

export function handleInterval(block: ethereum.Block): void {
  const protocol = getOrCreateYieldAggregator(block.timestamp)

  const vaults = protocol.vaultsArray
  for (let i = 0; i < vaults.length; i++) {
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
