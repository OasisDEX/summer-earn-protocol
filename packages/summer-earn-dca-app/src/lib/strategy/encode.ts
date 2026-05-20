import { getAddress } from 'viem'

import type { SubgraphStrategy } from '@/lib/subgraph/types'
import type { StrategyConfigTuple } from '@/types/strategy'

// Field order is binding — must match IDCAStrategyManager.StrategyConfig exactly,
// otherwise computeCommitment will mismatch the on-chain hash and any call that
// re-passes the config will revert with CommitmentMismatch.
export function toStrategyConfigStruct(s: SubgraphStrategy): StrategyConfigTuple {
  return {
    strategyId: BigInt(s.strategyId),
    owner: getAddress(s.owner.id),
    sourceVault: getAddress(s.sourceVault),
    targetVault: getAddress(s.targetVault),
    inAsset: getAddress(s.inAsset),
    outAsset: getAddress(s.outAsset),
    inAssetFeed: getAddress(s.inAssetFeed),
    outAssetFeed: getAddress(s.outAssetFeed),
    tradeAmount: BigInt(s.tradeAmount),
    interval: BigInt(s.interval),
    slippageBps: BigInt(s.slippageBps),
    maxPrice: BigInt(s.maxPrice),
    minPrice: BigInt(s.minPrice),
    endDate: BigInt(s.endDate),
    maxTrades: BigInt(s.maxTrades),
  }
}

// Build a tuple suitable for createStrategy. The contract assigns the real
// strategyId at write time, so we pass 0n here.
export function buildCreateTuple(input: {
  owner: `0x${string}`
  sourceVault: `0x${string}`
  targetVault: `0x${string}`
  inAsset: `0x${string}`
  outAsset: `0x${string}`
  inAssetFeed: `0x${string}`
  outAssetFeed: `0x${string}`
  tradeAmountShares: bigint
  intervalSeconds: bigint
  slippageBps: bigint
  maxPrice: bigint
  minPrice: bigint
  endDateUnix: bigint
  maxTrades: bigint
}): StrategyConfigTuple {
  return {
    strategyId: 0n,
    owner: getAddress(input.owner),
    sourceVault: getAddress(input.sourceVault),
    targetVault: getAddress(input.targetVault),
    inAsset: getAddress(input.inAsset),
    outAsset: getAddress(input.outAsset),
    inAssetFeed: getAddress(input.inAssetFeed),
    outAssetFeed: getAddress(input.outAssetFeed),
    tradeAmount: input.tradeAmountShares,
    interval: input.intervalSeconds,
    slippageBps: input.slippageBps,
    maxPrice: input.maxPrice,
    minPrice: input.minPrice,
    endDate: input.endDateUnix,
    maxTrades: input.maxTrades,
  }
}
