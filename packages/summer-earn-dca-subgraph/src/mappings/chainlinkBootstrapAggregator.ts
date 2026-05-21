import { Address, Bytes, dataSource, log } from '@graphprotocol/graph-ts'

import { AnswerUpdated } from '../../generated/BootstrapAggregatorUsdc/AggregatorV3Interface'
import { PriceRound } from '../../generated/schema'
import { getOrCreatePriceFeedWithImpl } from '../common/initializers'
import { proxyForBootstrapImpl } from './_bootstrapMap'

// `AnswerUpdated` handler for the **static** bootstrap aggregator dataSources
// (one per bootstrap feed). Unlike the dynamic `ChainlinkAggregator` template,
// static dataSources can't carry context — so we resolve `dataSource.address()`
// (impl) → proxy via the generated `_bootstrapMap.ts`, which is regenerated
// from `config/{network}.json` by `pnpm run prepare:base`.
export function handleBootstrapAnswerUpdated(event: AnswerUpdated): void {
  const impl = dataSource.address()
  const proxyAddress = proxyForBootstrapImpl(impl)
  if (proxyAddress.equals(Address.zero())) {
    log.warning('handleBootstrapAnswerUpdated: impl {} not in bootstrap map', [impl.toHexString()])
    return
  }

  // Lazily-create the feed entity if this is the very first round we see —
  // the bootstrap proxy dataSource only fires on `AggregatorConfirmed`, which
  // won't happen in the typical backfill window. `getOrCreatePriceFeedWithImpl`
  // is idempotent so we can call it unconditionally; AS-friendly too (no
  // re-assignment of a nullable `let`).
  const feed = getOrCreatePriceFeedWithImpl(proxyAddress, event.block, impl)

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

  if (roundId.gt(feed.latestRoundId)) {
    feed.latestRoundId = roundId
    feed.latestAnswer = event.params.current
    feed.latestUpdatedAt = event.params.updatedAt
    feed.save()
  }
}
