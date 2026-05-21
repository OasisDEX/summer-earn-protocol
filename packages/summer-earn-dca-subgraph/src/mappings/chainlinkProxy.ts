import { Bytes, DataSourceContext } from '@graphprotocol/graph-ts'

import { AggregatorConfirmed } from '../../generated/templates/ChainlinkProxy/AggregatorProxy'
import { AggregatorRotation } from '../../generated/schema'
import { ChainlinkAggregator } from '../../generated/templates'
import { getOrCreatePriceFeedWithImpl } from '../common/initializers'

// `AggregatorConfirmed(previous, latest)` fires when Chainlink rotates the
// aggregator implementation behind the proxy. We:
//   1. Spin up a new `ChainlinkAggregator` template instance bound to the
//      new impl address, carrying the proxy address in `context` so the
//      `AnswerUpdated` handler can resolve back to its `PriceFeed`.
//   2. Update `PriceFeed.aggregator` to the new impl.
//   3. Log the rotation for audit + FE chart annotation.
export function handleAggregatorConfirmed(event: AggregatorConfirmed): void {
  const proxyAddress = event.address
  const latest = event.params.latest
  const feed = getOrCreatePriceFeedWithImpl(proxyAddress, event.block, latest)

  const ctx = new DataSourceContext()
  ctx.setBytes('proxy', proxyAddress as Bytes)
  ChainlinkAggregator.createWithContext(latest, ctx)

  feed.aggregator = latest as Bytes
  feed.save()

  const rotationId =
    proxyAddress.toHexString() +
    '-' +
    event.block.number.toString() +
    '-' +
    event.logIndex.toString()
  const rotation = new AggregatorRotation(rotationId)
  rotation.feed = feed.id
  rotation.previous = event.params.previous as Bytes
  rotation.latest = latest as Bytes
  rotation.blockNumber = event.block.number
  rotation.timestamp = event.block.timestamp
  rotation.save()
}
