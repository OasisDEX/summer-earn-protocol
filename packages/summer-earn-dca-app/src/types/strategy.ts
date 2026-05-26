import type { Address, Hex } from 'viem'

// Field order is binding — must match IDCAStrategyManager.StrategyConfig
// exactly or the commitment hash diverges and every owner-gated call
// reverts CommitmentMismatch. strategyId lives outside the struct.
export interface StrategyConfigTuple {
  owner: Address
  sourceVault: Address
  targetVault: Address
  inAsset: Address
  outAsset: Address
  inAssetFeed: Address
  outAssetFeed: Address
  tradeAmount: bigint
  interval: bigint
  slippageBps: bigint
  maxPrice: bigint
  minPrice: bigint
  endDate: bigint
  maxTrades: bigint
}

export enum StrategyStatus {
  ACTIVE = 0,
  PAUSED = 1,
  COMPLETED = 2,
  CANCELLED = 3,
}

export type DisplayStrategyStatus = 'ACTIVE' | 'PAUSED' | 'CANCELLED' | 'COMPLETED'

export interface StrategyStateOnchain {
  status: StrategyStatus
  tradesExecuted: bigint
  nextTriggerAt: bigint
  lastScheduledAt: bigint
}

export interface StrategyConfigFormInput {
  sourceVault: Address
  targetVault: Address
  inAsset: Address
  outAsset: Address
  inAssetFeed: Address
  outAssetFeed: Address
  // Source-vault shares (uint160-bounded).
  tradeAmountShares: bigint
  intervalSeconds: bigint
  slippageBps: bigint
  // 1e18-scaled out/in execution-price ratio. 0 = no bound.
  maxPrice: bigint
  minPrice: bigint
  endDateUnix: bigint
  maxTrades: bigint
}

export interface CreateStrategyTxMeta {
  hash: Hex
  strategyId: bigint
}
