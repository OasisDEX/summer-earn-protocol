import { getAddress } from 'viem'

import type { SubgraphStrategy } from '@/lib/subgraph/types'
import type { StrategyConfigTuple } from '@/types/strategy'

// Field order is binding — must match IDCAStrategyManager.StrategyConfig exactly,
// otherwise computeCommitment will mismatch the on-chain hash and any call that
// re-passes the config will revert with CommitmentMismatch.
export function toStrategyConfigStruct(s: SubgraphStrategy): StrategyConfigTuple {
  return {
    owner: getAddress(s.owner.id),
    sourceVault: getAddress(s.sourceVault),
    targetVault: getAddress(s.targetVault),
    inAsset: getAddress(s.inAsset),
    outAsset: getAddress(s.outAsset),
    inAssetFeed: {
      feed: getAddress(s.inAssetFeed),
      maxStaleness: BigInt(s.inAssetFeedStaleness),
    },
    outAssetFeed: {
      feed: getAddress(s.outAssetFeed),
      maxStaleness: BigInt(s.outAssetFeedStaleness),
    },
    tradeAmount: BigInt(s.tradeAmount),
    interval: BigInt(s.interval),
    slippageBps: BigInt(s.slippageBps),
    maxPrice: BigInt(s.maxPrice),
    minPrice: BigInt(s.minPrice),
    endDate: BigInt(s.endDate),
    maxTrades: BigInt(s.maxTrades),
  }
}

export function buildCreateTuple(input: {
  owner: `0x${string}`
  sourceVault: `0x${string}`
  targetVault: `0x${string}`
  inAsset: `0x${string}`
  outAsset: `0x${string}`
  inAssetFeed: `0x${string}`
  outAssetFeed: `0x${string}`
  // Per-feed staleness (seconds); omitted/0 → contract default MAX_ORACLE_STALENESS.
  inAssetFeedStaleness?: bigint
  outAssetFeedStaleness?: bigint
  tradeAmountShares: bigint
  intervalSeconds: bigint
  slippageBps: bigint
  maxPrice: bigint
  minPrice: bigint
  endDateUnix: bigint
  maxTrades: bigint
}): StrategyConfigTuple {
  return {
    owner: getAddress(input.owner),
    sourceVault: getAddress(input.sourceVault),
    targetVault: getAddress(input.targetVault),
    inAsset: getAddress(input.inAsset),
    outAsset: getAddress(input.outAsset),
    inAssetFeed: {
      feed: getAddress(input.inAssetFeed),
      maxStaleness: input.inAssetFeedStaleness ?? 0n,
    },
    outAssetFeed: {
      feed: getAddress(input.outAssetFeed),
      maxStaleness: input.outAssetFeedStaleness ?? 0n,
    },
    tradeAmount: input.tradeAmountShares,
    interval: input.intervalSeconds,
    slippageBps: input.slippageBps,
    maxPrice: input.maxPrice,
    minPrice: input.minPrice,
    endDate: input.endDateUnix,
    maxTrades: input.maxTrades,
  }
}
