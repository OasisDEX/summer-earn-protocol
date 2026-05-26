import { Address, BigInt, Bytes, ethereum, log } from '@graphprotocol/graph-ts'

import { AggregatorProxy } from '../../generated/templates/ChainlinkProxy/AggregatorProxy'
import { ChainlinkProxy } from '../../generated/templates'
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
// doesn't exist, we eth_call `decimals()`/`description()` on the proxy and
// persist them along with the impl address the caller already knows.
//
// All callers go through `WithImpl` — either `handleProxyOnce` (resolves impl
// via `proxy.aggregator()`) or `handleAggregatorConfirmed` (reads `latest`
// from the event payload). That keeps the entity's `aggregator` field
// authoritative without an extra eth_call per access.
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

// Register a feed referenced by a strategy. Idempotent — `PriceFeed.load`
// short-circuits the second call. Just spins up the `ChainlinkProxy`
// template; the template's `handleProxyOnce` (kind: once block handler)
// then resolves the impl, seeds the `PriceFeed` entity, and registers a
// `ChainlinkAggregator` template instance for streaming `AnswerUpdated`
// events. Whole bootstrap flow happens in the subgraph — no off-chain
// prep step required.
export function registerFeed(proxyAddress: Address, block: ethereum.Block): void {
  if (PriceFeed.load(proxyAddress as Bytes) != null) {
    return
  }
  ChainlinkProxy.create(proxyAddress)
}
