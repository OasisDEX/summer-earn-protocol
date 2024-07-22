import { Address, ethereum, log } from '@graphprotocol/graph-ts'
import { FleetCommanderTemplate } from '../../generated/templates'
import { getOrCreateYieldAggregator } from '../common/initializers'

export function handleOnce(block: ethereum.Block): void {
  log.debug('handleOnce block.number: {}', [block.number.toString()])
  getOrCreateYieldAggregator()
  FleetCommanderTemplate.create(Address.fromString('0xa09E82322f351154a155f9e0f9e6ddbc8791C794'))
}
