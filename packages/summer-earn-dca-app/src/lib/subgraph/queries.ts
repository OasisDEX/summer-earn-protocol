// Hand-written GraphQL documents against packages/summer-earn-dca-subgraph/schema.graphql.
// No codegen — repo convention.

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
  amountIn
  amountOut
  tradesExecutedAfter
  executionTimestamp
  blockNumber
  logIndex
  txHash
`

// First page — no cursor predicate so The Graph doesn't choke on a null
// filter value. Use STRATEGIES_BY_OWNER_NEXT with the oldest seen
// `createdAt` to fetch subsequent pages. Keyset pagination scales O(log n)
// per page on Graph indexers — never use `skip` for entity lists.
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

// First page — no cursor predicate. Use EXECUTIONS_BY_STRATEGY_NEXT with
// the oldest seen `executionTimestamp` for subsequent pages.
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

// Fetch one time-window's worth of rounds plus the feed metadata.
// Window is [$from, $to) and is sized so a single 1000-record page
// covers the densest feed we index (~700 rounds/week for ETH/USD on Base).
// Called once per request in the windowed-parallel fetcher.
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

// Same as above without the one-shot feed metadata. Used for windows 2..N.
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
