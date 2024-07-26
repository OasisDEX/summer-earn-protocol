import { Address, ethereum } from '@graphprotocol/graph-ts'
import { BigIntConstants } from '../common/constants'
import {
  getOrCreateArk,
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
      const arks = _vault.arksArray
      for (let j = 0; j < arks.length; j++) {
        const _ark = getOrCreateArk(
          Address.fromString(vaults[i]),
          Address.fromString(arks[j]),
          block,
        )
        const arkDetails = getArkDetails(
          Address.fromString(vaults[i]),
          Address.fromString(arks[j]),
          block.number,
          _ark,
        )
        updateArk(arkDetails, block)
        getOrCreateArksHourlySnapshots(
          Address.fromString(vaults[i]),
          Address.fromString(arks[j]),
          block,
        )
      }
      if (
        block.timestamp.minus(protocol.lastUpdateTimestamp!).gt(BigIntConstants.SECONDS_PER_DAY)
      ) {
        getOrCreateVaultsDailySnapshots(Address.fromString(vaults[i]), block)
        for (let j = 0; j < arks.length; j++) {
          getOrCreateArksDailySnapshots(
            Address.fromString(vaults[i]),
            Address.fromString(arks[j]),
            block,
          )
        }
      }
    }
  }
}
