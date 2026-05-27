// Hand-written TS mirror of packages/summer-earn-dca-subgraph/schema.graphql.
// All BigInt fields arrive as strings over the wire — convert with BigInt(...)
// at the consumer (see lib/strategy/encode.ts).

export type SubgraphAddress = `0x${string}`

export interface SubgraphUser {
  id: SubgraphAddress
  createdAt: string
}

export type SubgraphStatus = 'ACTIVE' | 'PAUSED' | 'CANCELLED' | 'COMPLETED'

export interface SubgraphExecution {
  id: string
  amountIn: string
  amountOut: string
  tradesExecutedAfter: string
  executionTimestamp: string
  blockNumber: string
  logIndex: number
  txHash: SubgraphAddress
}

export interface SubgraphPriceFeed {
  id: SubgraphAddress
  decimals: number
  description: string | null
  firstSeenBlock: string
  firstSeenAt: string
  latestAnswer: string
  latestRoundId: string
  latestUpdatedAt: string
}

export interface SubgraphPriceRound {
  id: string
  roundId: string
  answer: string
  updatedAt: string
  blockNumber: string
}

export interface SubgraphStrategy {
  id: string
  strategyId: string
  owner: { id: SubgraphAddress }

  sourceVault: SubgraphAddress
  targetVault: SubgraphAddress
  inAsset: SubgraphAddress
  outAsset: SubgraphAddress
  inAssetFeed: SubgraphAddress
  outAssetFeed: SubgraphAddress

  tradeAmount: string
  interval: string
  slippageBps: string
  maxPrice: string
  minPrice: string
  endDate: string
  maxTrades: string

  status: SubgraphStatus
  nextTriggerAt: string
  lastScheduledAt: string
  tradesExecuted: string

  totalInAssetSwapped: string
  totalOutAssetReceived: string

  createdAt: string
  createdAtBlock: string
  updatedAt: string
  updatedAtBlock: string

  executions?: SubgraphExecution[]
}
