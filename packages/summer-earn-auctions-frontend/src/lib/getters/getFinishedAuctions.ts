import { CHAIN_CONFIGS } from '@/lib/config'

const FINISHED_AUCTIONS_QUERY = `
  query GetFinishedAuctions {
    auctions(
      where: { isFinalized: true }
      orderBy: endTimestamp
      orderDirection: desc
      first: 1000
    ) {
      id
      auctionId
      ark {
        id
        address
        commander
      }
      rewardToken {
        id
        name
        symbol
        decimals
      }
      buyToken {
        id
        name
        symbol
        decimals
      }
      startBlock
      endBlock
      startTimestamp
      endTimestamp
      startPrice
      endPrice
      tokensLeft
      tokensLeftNormalized
      isFinalized
      raft
      purchases(orderBy: timestamp, orderDirection: desc, first: 1000) {
        id
        buyer {
          id
        }
        tokensPurchased
        tokensPurchasedNormalized
        pricePerToken
        pricePerTokenNormalized
        totalCost
        totalCostNormalized
        timestamp
        marketPriceInUSDNormalized
        buyPriceInUSDNormalized
      }
    }
  }
`

export async function getAllFinishedAuctions() {
  return Promise.all(
    Object.entries(CHAIN_CONFIGS).map(async ([chainId, config]) => {
      const response = await fetch(config.subgraphEndpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          query: FINISHED_AUCTIONS_QUERY,
        }),
        next: {
          revalidate: 60 * 15, // 15 minutes since historical data changes less frequently
        },
      })

      const data = await response.json()
      return {
        chainId: CHAIN_CONFIGS[parseInt(chainId)].id,
        auctions: data.data.auctions,
      }
    }),
  )
}
