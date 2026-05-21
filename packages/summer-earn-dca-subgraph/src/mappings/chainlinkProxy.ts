import { Bytes, DataSourceContext, dataSource, ethereum, log } from '@graphprotocol/graph-ts'

import { AggregatorConfirmed, AggregatorProxy } from '../../generated/templates/ChainlinkProxy/AggregatorProxy'
import { AggregatorRotation } from '../../generated/schema'
import { ChainlinkAggregator } from '../../generated/templates'
import { getOrCreatePriceFeedWithImpl } from '../common/initializers'

// `kind: once` block handler — fires on the very first block this dataSource
// is active for. We resolve the current Chainlink impl via `proxy.aggregator()`,
// seed the `PriceFeed` entity, and create a `ChainlinkAggregator` template
// instance bound to the impl with the proxy address pinned in `context`. From
// here on, every `AnswerUpdated` from the impl streams into a `PriceRound`.
//
// For static bootstrap dataSources, "first block" is `feed-start-block`, so
// the dynamic aggregator template gets the full ~14d of backfill. For the
// dynamic `ChainlinkProxy` template (created via `registerFeed` when a user
// references a new proxy in a strategy), "first block" is the strategy-create
// block — no backfill, same as before.
export function handleProxyOnce(block: ethereum.Block): void {
  const proxyAddress = dataSource.address()

  // Idempotency: if we've already spun up the aggregator template (e.g. a
  // race with a follow-up `AggregatorConfirmed`), `PriceFeed.aggregator`
  // is already set — bail out.
  const proxy = AggregatorProxy.bind(proxyAddress)
  const aggRes = proxy.try_aggregator()
  if (aggRes.reverted) {
    log.warning('handleProxyOnce: {} aggregator() reverted — not a Chainlink proxy?', [
      proxyAddress.toHexString(),
    ])
    return
  }
  const impl = aggRes.value

  getOrCreatePriceFeedWithImpl(proxyAddress, block, impl)

  const ctx = new DataSourceContext()
  ctx.setBytes('proxy', proxyAddress as Bytes)
  ChainlinkAggregator.createWithContext(impl, ctx)
}

// `AggregatorConfirmed(previous, latest)` fires when Chainlink rotates the
// impl behind the proxy. We register a new aggregator template for `latest`
// (with the proxy address in context), update `PriceFeed.aggregator`, and log
// the rotation for audit.
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
