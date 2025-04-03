import { Bytes, ethereum } from '@graphprotocol/graph-ts'
import { TimeHelper } from '../generated/schema'
import { protocolConfig } from './config/protocolConfig'
import { BigIntConstants } from './constants/common'
import { handleInterestRate } from './utils/interestRateHandlers'

export function handleBlock(block: ethereum.Block): void {
  let timeHelper = TimeHelper.load(Bytes.fromI32(0))
  if (!timeHelper) {
    timeHelper = new TimeHelper(Bytes.fromI32(0))
    timeHelper.lastUpdateTimestamp = BigIntConstants.ZERO
  }

  // Calculate the start of the current 10-minute epoch
  const tenMinuteEpochStart = block.timestamp
    .div(BigIntConstants.TEN_MINUTES_IN_SECONDS)
    .times(BigIntConstants.TEN_MINUTES_IN_SECONDS)

  if (timeHelper.lastUpdateTimestamp.lt(tenMinuteEpochStart)) {
    for (let i = 0; i < protocolConfig.length; i++) {
      const protocol = protocolConfig[i]
      for (let j = 0; j < protocol.products.length; j++) {
        const product = protocol.products[j]
        if (block.number.ge(product.startBlock)) {
          handleInterestRate(block, protocol.name, product, tenMinuteEpochStart)
        }
      }
    }
    timeHelper.lastUpdateTimestamp = tenMinuteEpochStart
  }
  timeHelper.save()
}
