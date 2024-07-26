import { Address, BigInt, ethereum } from '@graphprotocol/graph-ts'
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

export function handleOnce(block: ethereum.Block): void {
  getOrCreateVault(Address.fromString('0x66b5277938617daAdE875D2913495A8d13cf3045'), block)
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

  if (!protocol.lastUpdateTimestamp) {
    protocol.lastUpdateTimestamp = block.timestamp
    protocol.save()
    handleOnce(block)
    return
  }

  protocol.lastUpdateTimestamp = block.timestamp
  protocol.save()

  const vaults = protocol.vaultsArray
  for (let i = 0; i < vaults.length; i++) {
    const vaultAddress = Address.fromString(vaults[i])
    updateVaultAndArks(vaultAddress, block, protocol.lastUpdateTimestamp)
  }
}

function hasDayPassed(lastUpdateTimestamp: BigInt | null, currentTimestamp: BigInt): boolean {
  return lastUpdateTimestamp
    ? currentTimestamp.minus(lastUpdateTimestamp).gt(BigIntConstants.SECONDS_PER_DAY)
    : false
}
