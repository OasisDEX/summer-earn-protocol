export const ACCOUNT_RECEIPTS = /* GraphQL */ `
  query AccountReceipts($account: ID!) {
    account(id: $account) {
      id
      roundsVaultReceipts(first: 1000, where: { balance_gt: "0" }) {
        id
        balance
        lastUpdated
        round {
          id
          roundId
          state
          openedAt
          closedAt
          settledAt
          exchangeRateBase
          exchangeRateQuote
          isEmpty
        }
        vault {
          id
          flavor
          minPositionSize
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
            targetVault {
              id
              name
            }
          }
        }
      }
    }
  }
`

export const RECEIPTS_BY_VAULT = /* GraphQL */ `
  query ReceiptsByVault($account: String!, $vault: String!) {
    receipts(
      first: 1000
      where: { account: $account, vault: $vault, balance_gt: "0" }
      orderBy: lastUpdated
      orderDirection: desc
    ) {
      id
      balance
      lastUpdated
      round {
        id
        roundId
        state
        openedAt
        closedAt
        settledAt
        exchangeRateBase
        exchangeRateQuote
        isEmpty
      }
      vault {
        id
        flavor
        minPositionSize
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
      }
    }
  }
`
