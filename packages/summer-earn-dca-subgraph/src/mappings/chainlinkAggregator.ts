import { Bytes, dataSource, log } from '@graphprotocol/graph-ts'

import { AnswerUpdated } from '../../generated/templates/ChainlinkAggregator/AggregatorV3Interface'
import { PriceFeed, PriceRound } from '../../generated/schema'

// `AnswerUpdated(current, roundId, updatedAt)` fires from the current
// aggregator implementation behind the Chainlink proxy. Template `context`
// pins the proxy address at create-time, so we can resolve back to the
// `PriceFeed` row (keyed by proxy) without an `eth_call` per event.
export function handleAnswerUpdated(event: AnswerUpdated): void {
  const ctx = dataSource.context()
  const proxyAddress = ctx.getBytes('proxy')

  const feed = PriceFeed.load(proxyAddress)
  if (feed == null) {
    log.warning('handleAnswerUpdated: no PriceFeed for proxy {}', [proxyAddress.toHexString()])
    return
  }

  const roundId = event.params.roundId
  const id = proxyAddress.toHexString() + '-' + roundId.toString()
  const round = new PriceRound(id)
  round.feed = feed.id
  round.roundId = roundId
  round.answer = event.params.current
  round.updatedAt = event.params.updatedAt
  round.blockNumber = event.block.number
  round.txHash = event.transaction.hash as Bytes
  round.logIndex = event.logIndex.toI32()
  round.save()

  // Denormalised latest for cheap reads from the FE.
  if (roundId.gt(feed.latestRoundId)) {
    feed.latestRoundId = roundId
    feed.latestAnswer = event.params.current
    feed.latestUpdatedAt = event.params.updatedAt
    feed.save()
  }
}
