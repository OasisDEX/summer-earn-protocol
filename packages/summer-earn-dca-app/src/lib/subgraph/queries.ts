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

export const STRATEGIES_BY_OWNER = /* GraphQL */ `
  query StrategiesByOwner($owner: Bytes!, $first: Int = 50, $skip: Int = 0) {
    strategies(
      where: { owner: $owner }
      first: $first
      skip: $skip
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

export const EXECUTIONS_BY_STRATEGY = /* GraphQL */ `
  query ExecutionsByStrategy($strategyId: String!, $first: Int = 25, $skip: Int = 0) {
    executions(
      where: { strategy: $strategyId }
      first: $first
      skip: $skip
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
  id
  roundId
  answer
  updatedAt
  blockNumber
`

// Single round-page request; the caller pages with `skip` until points stop
// arriving. The subgraph default cap is 1000 per request, which is generous
// for any range we display.
export const PRICE_HISTORY = /* GraphQL */ `
  query PriceHistory(
    $feed: Bytes!
    $from: BigInt!
    $first: Int = 1000
    $skip: Int = 0
  ) {
    priceFeed(id: $feed) {
      ${PRICE_FEED_FIELDS}
    }
    priceRounds(
      where: { feed: $feed, updatedAt_gte: $from }
      first: $first
      skip: $skip
      orderBy: updatedAt
      orderDirection: asc
    ) {
      ${PRICE_ROUND_FIELDS}
    }
  }
`
