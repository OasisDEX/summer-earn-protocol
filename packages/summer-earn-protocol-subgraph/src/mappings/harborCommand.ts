import { Address, BigInt, ethereum } from '@graphprotocol/graph-ts'
import { FleetCommanderEnlisted } from '../../generated/HarborCommand/HarborCommand'
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
import { updateArk } from './entities/ark'
import { updateVault } from './entities/vault'

export function handleFleetCommanderEnlisted(event: FleetCommanderEnlisted): void {
  getOrCreateVault(event.params.fleetCommander, event.block)
}

function updateArkAndSnapshots(
  vaultAddress: Address,
  arkAddress: Address,
  block: ethereum.Block,
  protocolLastUpdateTimestamp: BigInt | null,
): void {
  const arkDetails = getArkDetails(vaultAddress, arkAddress, block)
  updateArk(arkDetails, block)
  getOrCreateArksHourlySnapshots(vaultAddress, arkAddress, block)

  if (hasDayPassed(protocolLastUpdateTimestamp, block.timestamp)) {
    getOrCreateArksDailySnapshots(vaultAddress, arkAddress, block)
  }
}

function updateVaultAndArks(
  vaultAddress: Address,
  block: ethereum.Block,
  protocolLastUpdateTimestamp: BigInt | null,
): void {
  const vault = getOrCreateVault(vaultAddress, block)
  const vaultDetails = getVaultDetails(vaultAddress, block)
  updateVault(vaultDetails, block)
  getOrCreateVaultsHourlySnapshots(vaultAddress, block)

  const arks = vault.arksArray
  for (let j = 0; j < arks.length; j++) {
    const arkAddress = Address.fromString(arks[j])
    updateArkAndSnapshots(vaultAddress, arkAddress, block, protocolLastUpdateTimestamp)
  }

  if (hasDayPassed(protocolLastUpdateTimestamp, block.timestamp)) {
    getOrCreateVaultsDailySnapshots(vaultAddress, block)
  }
}

export function handleInterval(block: ethereum.Block): void {
  const protocol = getOrCreateYieldAggregator()

  const vaults = protocol.vaultsArray
  for (let i = 0; i < vaults.length; i++) {
    const vaultAddress = Address.fromString(vaults[i])
    updateVaultAndArks(vaultAddress, block, protocol.lastUpdateTimestamp)
  }
  if (hasDayPassed(protocol.lastUpdateTimestamp, block.timestamp)) {
    protocol.lastUpdateTimestamp = block.timestamp
  }
  protocol.save()
}

function hasDayPassed(lastUpdateTimestamp: BigInt | null, currentTimestamp: BigInt): boolean {
  if (!lastUpdateTimestamp || lastUpdateTimestamp.equals(BigIntConstants.ZERO)) {
    return true // Create initial snapshot if no previous timestamp or if it's zero
  }
  return currentTimestamp.minus(lastUpdateTimestamp).ge(BigIntConstants.SECONDS_PER_DAY)
}
