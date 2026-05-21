import { Address, BigInt, Bytes, DataSourceContext, ethereum, log } from '@graphprotocol/graph-ts'

import { AggregatorProxy } from '../../generated/templates/ChainlinkProxy/AggregatorProxy'
import { ChainlinkAggregator, ChainlinkProxy } from '../../generated/templates'
import { PriceFeed, Strategy, User } from '../../generated/schema'
import { BigIntConstants } from './constants'

export function getOrCreateUser(address: Address, block: ethereum.Block): User {
  let user = User.load(address)
  if (user == null) {
    user = new User(address)
    user.createdAt = block.timestamp
    user.save()
  }
  return user
}

export function loadStrategyOrWarn(strategyId: BigInt, context: string): Strategy | null {
  const id = strategyId.toString()
  const s = Strategy.load(id)
  if (s == null) {
    log.warning('{}: strategy {} not found', [context, id])
  }
  return s
}

// Idempotent `PriceFeed` accessor keyed by proxy address. If the entity
// doesn't exist, we eth_call `decimals()`/`description()`/`aggregator()` on
// the proxy once and persist them. The `WithImpl` variant skips the
// `aggregator()` call when the caller already knows the impl (e.g. the
// bootstrap aggregator handler resolves impl via `dataSource.address()`).
export function getOrCreatePriceFeed(
  proxyAddress: Address,
  block: ethereum.Block,
): PriceFeed {
  const existing = PriceFeed.load(proxyAddress as Bytes)
  if (existing != null) return existing

  const proxy = AggregatorProxy.bind(proxyAddress)
  const aggRes = proxy.try_aggregator()
  const impl = aggRes.reverted ? Address.zero() : aggRes.value
  return initPriceFeed(proxyAddress, block, impl)
}

export function getOrCreatePriceFeedWithImpl(
  proxyAddress: Address,
  block: ethereum.Block,
  impl: Address,
): PriceFeed {
  const existing = PriceFeed.load(proxyAddress as Bytes)
  if (existing != null) return existing
  return initPriceFeed(proxyAddress, block, impl)
}

function initPriceFeed(proxyAddress: Address, block: ethereum.Block, impl: Address): PriceFeed {
  const feed = new PriceFeed(proxyAddress as Bytes)
  const proxy = AggregatorProxy.bind(proxyAddress)

  const decRes = proxy.try_decimals()
  feed.decimals = decRes.reverted ? 8 : decRes.value
  const descRes = proxy.try_description()
  feed.description = descRes.reverted ? null : descRes.value

  feed.aggregator = impl as Bytes
  feed.firstSeenBlock = block.number
  feed.firstSeenAt = block.timestamp
  feed.latestAnswer = BigIntConstants.ZERO
  feed.latestRoundId = BigIntConstants.ZERO
  feed.latestUpdatedAt = BigIntConstants.ZERO
  feed.save()

  return feed
}

// Register a feed referenced by a strategy. Idempotent — graph-node ignores
// duplicate template creates. Called preemptively from
// `handleStrategyCreated`/`handleStrategyEdited` so user-supplied feeds
// start streaming `AnswerUpdated` events the moment we see them.
export function registerFeed(proxyAddress: Address, block: ethereum.Block): void {
  if (PriceFeed.load(proxyAddress as Bytes) != null) {
    return
  }

  // Resolve current impl once. If the address isn't a real Chainlink proxy
  // the call reverts and we skip registration — the app falls through to
  // DeFiLlama via the composite price client.
  const proxy = AggregatorProxy.bind(proxyAddress)
  const aggRes = proxy.try_aggregator()
  if (aggRes.reverted) {
    log.warning('registerFeed: {} is not a Chainlink proxy (aggregator() reverted)', [
      proxyAddress.toHexString(),
    ])
    return
  }
  const impl = aggRes.value

  getOrCreatePriceFeedWithImpl(proxyAddress, block, impl)

  ChainlinkProxy.create(proxyAddress)

  const ctx = new DataSourceContext()
  ctx.setBytes('proxy', proxyAddress as Bytes)
  ChainlinkAggregator.createWithContext(impl, ctx)
}
