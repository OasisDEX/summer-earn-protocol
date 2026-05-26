export const INSTITUTIONS_LIST = /* GraphQL */ `
  query InstitutionsList {
    institutions(first: 100, where: { active: true }) {
      id
      active
      configurationManager
      protocolAccessManager
      admiralsQuarters
      harborCommand
      createdTimestamp
      createdBlockNumber
      vaults {
        id
        name
        symbol
      }
    }
  }
`

export const INSTITUTION_BY_CONFIGURATION_MANAGER = /* GraphQL */ `
  query InstitutionByCm($cm: String!) {
    institutions(first: 1, where: { configurationManager: $cm }) {
      id
      active
      configurationManager
      protocolAccessManager
      admiralsQuarters
      harborCommand
      createdTimestamp
      createdBlockNumber
    }
  }
`

export const INSTITUTION_DETAIL = /* GraphQL */ `
  query InstitutionDetail($id: ID!) {
    institution(id: $id) {
      id
      active
      configurationManager
      protocolAccessManager
      admiralsQuarters
      harborCommand
      createdTimestamp
      vaults {
        id
        name
        symbol
        details
        isWhitelistOpen
        depositCap
        minimumBufferBalance
        tipRate
        inputToken {
          id
          symbol
          decimals
        }
        totalValueLockedUSD
        pricePerShare
        calculatedApr
        apr7d
        apr30d
        apr90d
        arks {
          id
          productId
          name
          depositCap
          inputToken {
            id
            symbol
            decimals
          }
        }
        bufferArk {
          id
        }
        roundsVaultPair {
          id
          active
          institutionId
          registeredAt
          lastUpdated
          targetVault {
            id
            name
            symbol
          }
          inputVault {
            id
            flavor
            currentRound
            minPositionSize
            cumulativeDepositsQueued
            cumulativeExchangeAssetWithdrawn
            currentRoundReceiptSupply
            pendingSettlementAmount
            createdAt
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
          outputVault {
            id
            flavor
            currentRound
            minPositionSize
            cumulativeDepositsQueued
            cumulativeExchangeAssetWithdrawn
            currentRoundReceiptSupply
            pendingSettlementAmount
            createdAt
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
    }
  }
`
