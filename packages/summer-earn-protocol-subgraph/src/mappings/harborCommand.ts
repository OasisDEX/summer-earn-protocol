import { Address, BigInt, ethereum } from '@graphprotocol/graph-ts'
import { FleetCommanderEnlisted } from '../../generated/HarborCommand/HarborCommand'
import { YieldAggregator } from '../../generated/schema'
import { BigIntConstants } from '../common/constants'
import {
  getOrCreateArksDailySnapshots,
  getOrCreateArksHourlySnapshots,
  getOrCreateVault,
  getOrCreateVaultsDailySnapshots,
  getOrCreateVaultsHourlySnapshots,
  getOrCreateYieldAggregator,
} from '../common/initializers'
import { getArkDetails } from '../utils/ark'
import { getVaultDetails } from '../utils/vault'
import { handleVaultRate } from '../utils/vaultRateHandlers'
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
): void {
  getOrCreateVaultsHourlySnapshots(vaultAddress, block)
  if (shouldUpdateDaily) {
    getOrCreateVaultsDailySnapshots(vaultAddress, block)
  }
  handleVaultRate(block, vaultAddress.toHexString())
}

// Main update orchestration functions
function processHourlyVaultUpdate(
  vaultAddress: Address,
  block: ethereum.Block,
  protocolLastDailyUpdateTimestamp: BigInt | null,
  protocolLastHourlyUpdateTimestamp: BigInt | null,
): void {
  const dayPassed = hasDayPassed(protocolLastDailyUpdateTimestamp, block.timestamp)
  const hourPassed = hasHourPassed(protocolLastHourlyUpdateTimestamp, block.timestamp)

  if (hourPassed) {
    const vault = getOrCreateVault(vaultAddress, block)

    // Update main data
    updateVaultData(vaultAddress, block)
    updateVaultSnapshots(vaultAddress, block, dayPassed)

    // Update associated arks
    const arks = vault.arksArray
    for (let j = 0; j < arks.length; j++) {
      const arkAddress = Address.fromString(arks[j])
      updateArkData(vaultAddress, arkAddress, block)
      updateArkSnapshots(vaultAddress, arkAddress, block, dayPassed)
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
    )
  }

  updateProtocolTimestamps(protocol, block)
  protocol.save()
}

function updateProtocolTimestamps(protocol: YieldAggregator, block: ethereum.Block): void {
  if (hasHourPassed(protocol.lastHourlyUpdateTimestamp, block.timestamp)) {
    const firstSecondOfThisHour = block.timestamp
      .div(BigIntConstants.SECONDS_PER_HOUR)
      .times(BigIntConstants.SECONDS_PER_HOUR)

    protocol.lastHourlyUpdateTimestamp = firstSecondOfThisHour

    if (hasDayPassed(protocol.lastDailyUpdateTimestamp, block.timestamp)) {
      protocol.lastDailyUpdateTimestamp = firstSecondOfThisHour
    }

    protocol.save()
  }
}

function hasDayPassed(lastUpdateTimestamp: BigInt | null, currentTimestamp: BigInt): boolean {
  if (!lastUpdateTimestamp || lastUpdateTimestamp.equals(BigIntConstants.ZERO)) {
    return true // Create initial snapshot if no previous timestamp or if it's zero
  }
  const currentDayTimestamp = currentTimestamp
    .div(BigIntConstants.SECONDS_PER_DAY)
    .times(BigIntConstants.SECONDS_PER_DAY)
  const previousDayTimestamp = lastUpdateTimestamp
  return !currentDayTimestamp.equals(previousDayTimestamp)
}

function hasHourPassed(lastUpdateTimestamp: BigInt | null, currentTimestamp: BigInt): boolean {
  if (!lastUpdateTimestamp || lastUpdateTimestamp.equals(BigIntConstants.ZERO)) {
    return true // Create initial snapshot if no previous timestamp or if it's zero
  }
  const currentHourTimestamp = currentTimestamp
    .div(BigIntConstants.SECONDS_PER_HOUR)
    .times(BigIntConstants.SECONDS_PER_HOUR)
  const previousHourTimestamp = lastUpdateTimestamp
  return !currentHourTimestamp.equals(previousHourTimestamp)
}
