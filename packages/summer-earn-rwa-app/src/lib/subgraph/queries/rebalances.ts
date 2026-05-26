export const REBALANCES_FOR_FLEET = /* GraphQL */ `
  query RebalancesForFleet($fleet: String!, $first: Int = 25) {
    rebalances(
      first: $first
      where: { vault: $fleet }
      orderBy: timestamp
      orderDirection: desc
    ) {
      id
      hash
      timestamp
      amount
      amountUSD
      asset {
        id
        symbol
        decimals
      }
      from {
        id
        productId
        name
      }
      to {
        id
        productId
        name
      }
      fromPostAction {
        totalValueLockedUSD
        inputTokenBalance
      }
      toPostAction {
        totalValueLockedUSD
        inputTokenBalance
      }
    }
  }
`
