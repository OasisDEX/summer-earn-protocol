import { ethereum } from '@graphprotocol/graph-ts'
import { protocolConfig } from './config/protocolConfig'
import { handleInterestRate } from './utils/interestRateHandlers'

export function handleBlock(block: ethereum.Block): void {
  for (let i = 0; i < protocolConfig.length; i++) {
    const protocol = protocolConfig[i]
    for (let j = 0; j < protocol.products.length; j++) {
      const product = protocol.products[j]
      if (block.number.ge(product.startBlock)) {
        handleInterestRate(block, protocol.name, product)
      }
    }
  }
}
