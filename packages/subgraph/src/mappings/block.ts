import { Address, ethereum, log } from '@graphprotocol/graph-ts'
import { SECONDS_PER_DAY } from '../common/constants'
import {
  getOrCreateVault,
  getOrCreateVaultsDailySnapshots,
  getOrCreateVaultsHourlySnapshots,
  getOrCreateYieldAggregator,
} from '../common/initializers'
import { getVaultDetails } from '../utils/vault'
import { updateVault } from './entities/vault'

let lastUpdateTimestamp = 0

export function handleOnce(block: ethereum.Block): void {
  log.debug('handleOnce block.number: {}', [block.number.toString()])
  getOrCreateYieldAggregator()
  getOrCreateVault(Address.fromString('0xa09E82322f351154a155f9e0f9e6ddbc8791C794'), block)
}

export function handleInterval(block: ethereum.Block): void {
  log.error('handleInterval block.number: {}', [block.number.toString()])
  const protocol = getOrCreateYieldAggregator()
  const vaults = protocol.vaultsArray
  for (let i = 0; i < vaults.length; i++) {
    log.error('vaults[i]: {}', [vaults[i]])
    const _vault = getOrCreateVault(Address.fromString(vaults[i]), block)
    const vaultDetails = getVaultDetails(Address.fromString(vaults[i]), block.number, _vault)
    updateVault(vaultDetails, block)
    getOrCreateVaultsHourlySnapshots(Address.fromString(vaults[i]), block)
    if (block.timestamp.toI32() - lastUpdateTimestamp > SECONDS_PER_DAY) {
      getOrCreateVaultsDailySnapshots(Address.fromString(vaults[i]), block)
    }
  }
}
