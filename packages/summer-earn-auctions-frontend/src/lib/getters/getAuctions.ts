import { CHAIN_CONFIGS } from '../config'
const AUCTIONS_QUERY = `
  query GetAuctions {
    auctions(where: { isFinalized: false, startTimestamp_gt: 1763714837 }) {
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
      kickerRewardPercentage
      decayType
      duration
      isFinalized
      raft
    }
  }
`
export async function getAllAuctions() {
  return Promise.all(
    Object.entries(CHAIN_CONFIGS).map(async ([chainId, config]) => {
      const response = await fetch(config.subgraphEndpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          query: AUCTIONS_QUERY,
        }),
        next: {
          revalidate: 0, // 5 minutes
        },
      })

      const data = await response.json()
      return {
        chainId: parseInt(chainId),
        auctions: data.data.auctions,
      }
    }),
  )
}
