export const FLEET_DETAIL = /* GraphQL */ `
  query FleetDetail($id: ID!) {
    vault(id: $id) {
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
      apr180d
      apr365d
      bufferArk {
        id
      }
      arks {
        id
        productId
        name
        depositCap
        totalValueLockedUSD
        inputTokenBalance
        inputToken {
          id
          symbol
          decimals
        }
      }
      roundsVaultPair {
        id
        active
        registeredAt
        targetVault {
          id
          name
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
`
