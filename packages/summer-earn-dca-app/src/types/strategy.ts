import type { Address, Hex } from 'viem'

// TS mirror of IDCAStrategyManager.StrategyConfig — field order is binding.
// Anything that changes here must change in lockstep with the on-chain struct,
// or commitment checks will revert.
export interface StrategyConfigTuple {
  strategyId: bigint
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

// IDCAStrategyManager.Status — uint8 enum.
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
  // Persisted as source-vault shares (uint160-bounded).
  tradeAmountShares: bigint
  intervalSeconds: bigint
  slippageBps: bigint
  // Stored at feed precision (0 = no bound).
  maxPrice: bigint
  minPrice: bigint
  endDateUnix: bigint
  maxTrades: bigint
}

export interface CreateStrategyTxMeta {
  hash: Hex
  strategyId: bigint
}
