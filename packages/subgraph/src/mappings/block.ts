import { Address, ethereum, log } from '@graphprotocol/graph-ts'
import { BigIntConstants, SECONDS_PER_DAY } from '../common/constants'
import {
  getOrCreateVault,
  getOrCreateVaultsDailySnapshots,
  getOrCreateVaultsHourlySnapshots,
  getOrCreateYieldAggregator,
} from '../common/initializers'
import { getVaultDetails } from '../utils/vault'
import { updateVault } from './entities/vault'


export function handleOnce(block: ethereum.Block): void {
  getOrCreateVault(Address.fromString('0xa09E82322f351154a155f9e0f9e6ddbc8791C794'), block)
}

export function handleInterval(block: ethereum.Block): void {
  const protocol = getOrCreateYieldAggregator()
  if (!protocol.lastUpdateTimestamp) {
    protocol.lastUpdateTimestamp = block.timestamp
    protocol.save()
    handleOnce(block)
  } else {
    const protocol = getOrCreateYieldAggregator()
    protocol.lastUpdateTimestamp = block.timestamp
    protocol.save()

    const vaults = protocol.vaultsArray
    for (let i = 0; i < vaults.length; i++) {
      const _vault = getOrCreateVault(Address.fromString(vaults[i]), block)
      const vaultDetails = getVaultDetails(Address.fromString(vaults[i]), block.number, _vault)
      updateVault(vaultDetails, block)
      getOrCreateVaultsHourlySnapshots(Address.fromString(vaults[i]), block)
      if (block.timestamp.minus(protocol.lastUpdateTimestamp!).gt(BigIntConstants.SECONDS_PER_DAY)) {
        getOrCreateVaultsDailySnapshots(Address.fromString(vaults[i]), block)
      }
    }

  }
}
