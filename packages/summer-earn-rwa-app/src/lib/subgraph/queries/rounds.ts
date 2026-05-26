export const ROUNDS_VAULT = /* GraphQL */ `
  query RoundsVault($id: ID!) {
    roundsVault(id: $id) {
      id
      flavor
      currentRound
      minPositionSize
      cumulativeDepositsQueued
      cumulativeExchangeAssetWithdrawn
      currentRoundReceiptSupply
      pendingSettlementAmount
      createdAt
      createdAtBlock
      underlyingToken {
        id
        symbol
        decimals
      }
      exchangeAssetToken {
        id
        symbol
        decimals
      }
      pair {
        id
        active
        targetVault {
          id
          name
        }
      }
    }
  }
`

export const ROUNDS_FOR_VAULT = /* GraphQL */ `
  query RoundsForVault($vault: String!, $first: Int = 50, $cursor: BigInt) {
    rounds(
      first: $first
      where: { vault: $vault, roundId_lt: $cursor }
      orderBy: roundId
      orderDirection: desc
    ) {
      id
      roundId
      state
      openedAt
      openedAtBlock
      closedAt
      closedAtBlock
      settledAt
      settledAtBlock
      exchangeRateBase
      exchangeRateQuote
      exchangeRateDecimal
      totalReceiptSupplyAtClose
      inputAssetsDeposited
      inputSharesReceived
      outputSharesRedeemed
      outputAssetsReturned
      retriedCount
      rolledBack
    }
  }
`

export const ROUNDS_VAULT_WITH_RECENT_ROUNDS = /* GraphQL */ `
  query RoundsVaultWithRecentRounds($id: ID!, $first: Int = 30) {
    roundsVault(id: $id) {
      id
      flavor
      currentRound
      minPositionSize
      cumulativeDepositsQueued
      cumulativeExchangeAssetWithdrawn
      currentRoundReceiptSupply
      pendingSettlementAmount
      underlyingToken {
        id
        symbol
        decimals
      }
      exchangeAssetToken {
        id
        symbol
        decimals
      }
      rounds(first: $first, orderBy: roundId, orderDirection: desc) {
        id
        roundId
        state
        openedAt
        closedAt
        settledAt
        exchangeRateBase
        exchangeRateQuote
        exchangeRateDecimal
        totalReceiptSupplyAtClose
        inputAssetsDeposited
        inputSharesReceived
        outputSharesRedeemed
        outputAssetsReturned
        retriedCount
        rolledBack
      }
    }
  }
`
