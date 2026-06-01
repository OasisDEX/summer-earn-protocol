// No codegen — keep these hand-written and in sync with schema.graphql.

const STRATEGY_FIELDS = /* GraphQL */ `
  id
  strategyId
  owner { id }
  sourceVault
  targetVault
  inAsset
  outAsset
  inAssetFeed
  outAssetFeed
  tradeAmount
  interval
  slippageBps
  maxPrice
  minPrice
  endDate
  maxTrades
  status
  nextTriggerAt
  lastScheduledAt
  tradesExecuted
  totalInAssetSwapped
  totalOutAssetReceived
  createdAt
  createdAtBlock
  updatedAt
  updatedAtBlock
`

const EXECUTION_FIELDS = /* GraphQL */ `
  id
  inAssets
  outAssets
  inShares
  outShares
  tradesExecutedAfter
  executionTimestamp
  blockNumber
  logIndex
  txHash
`

// First/next pattern: The Graph rejects null filter values, so the cursor
// predicate has to be absent entirely on the first page rather than nullable.
// Never use `skip` for entity lists — keyset pagination only.
export const STRATEGIES_BY_OWNER_FIRST = /* GraphQL */ `
  query StrategiesByOwnerFirst($owner: Bytes!, $first: Int = 50) {
    strategies(
      where: { owner: $owner }
      first: $first
      orderBy: createdAt
      orderDirection: desc
    ) {
      ${STRATEGY_FIELDS}
      executions(first: 5, orderBy: executionTimestamp, orderDirection: desc) {
        ${EXECUTION_FIELDS}
      }
    }
  }
`

export const STRATEGIES_BY_OWNER_NEXT = /* GraphQL */ `
  query StrategiesByOwnerNext(
    $owner: Bytes!
    $first: Int = 50
    $cursorCreatedAt: BigInt!
  ) {
    strategies(
      where: {
        owner: $owner
        createdAt_lt: $cursorCreatedAt
      }
      first: $first
      orderBy: createdAt
      orderDirection: desc
    ) {
      ${STRATEGY_FIELDS}
      executions(first: 5, orderBy: executionTimestamp, orderDirection: desc) {
        ${EXECUTION_FIELDS}
      }
    }
  }
`

export const STRATEGY_BY_ID = /* GraphQL */ `
  query StrategyById($id: String!, $executionsFirst: Int = 50) {
    strategy(id: $id) {
      ${STRATEGY_FIELDS}
      executions(first: $executionsFirst, orderBy: executionTimestamp, orderDirection: desc) {
        ${EXECUTION_FIELDS}
      }
    }
  }
`

export const EXECUTIONS_BY_STRATEGY_FIRST = /* GraphQL */ `
  query ExecutionsByStrategyFirst($strategyId: String!, $first: Int = 25) {
    executions(
      where: { strategy: $strategyId }
      first: $first
      orderBy: executionTimestamp
      orderDirection: desc
    ) {
      ${EXECUTION_FIELDS}
    }
  }
`

export const EXECUTIONS_BY_STRATEGY_NEXT = /* GraphQL */ `
  query ExecutionsByStrategyNext(
    $strategyId: String!
    $first: Int = 25
    $cursorExecutionTimestamp: BigInt!
  ) {
    executions(
      where: {
        strategy: $strategyId
        executionTimestamp_lt: $cursorExecutionTimestamp
      }
      first: $first
      orderBy: executionTimestamp
      orderDirection: desc
    ) {
      ${EXECUTION_FIELDS}
    }
  }
`

const PRICE_FEED_FIELDS = /* GraphQL */ `
  id
  decimals
  description
  firstSeenBlock
  firstSeenAt
  latestAnswer
  latestRoundId
  latestUpdatedAt
`

const PRICE_ROUND_FIELDS = /* GraphQL */ `
  answer
  updatedAt
`

// [$from, $to) — window size chosen so a single 1000-record page covers
// the densest feed we index (~700 rounds/week for ETH/USD on Base).
export const PRICE_WINDOW_FIRST = /* GraphQL */ `
  query PriceWindowFirst($feed: Bytes!, $from: BigInt!, $to: BigInt!) {
    priceFeed(id: $feed) {
      ${PRICE_FEED_FIELDS}
    }
    priceRounds(
      where: { feed: $feed, updatedAt_gte: $from, updatedAt_lt: $to }
      first: 1000
      orderBy: updatedAt
      orderDirection: asc
    ) {
      ${PRICE_ROUND_FIELDS}
    }
  }
`

export const PRICE_WINDOW = /* GraphQL */ `
  query PriceWindow($feed: Bytes!, $from: BigInt!, $to: BigInt!) {
    priceRounds(
      where: { feed: $feed, updatedAt_gte: $from, updatedAt_lt: $to }
      first: 1000
      orderBy: updatedAt
      orderDirection: asc
    ) {
      ${PRICE_ROUND_FIELDS}
    }
  }
`
