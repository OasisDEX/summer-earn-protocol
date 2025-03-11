import { CHAIN_CONFIGS } from '@/lib/config';
const AUCTIONS_QUERY = `
  query GetAuctions {
    auctions(where: { isFinalized: false }) {
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
    }
  }
`;
export async function GET() {
  try {
    const allAuctions = await Promise.all(
      Object.entries(CHAIN_CONFIGS).map(async ([chainId, config]) => {
        const response = await fetch(config.subgraphEndpoint, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            query: AUCTIONS_QUERY
          }),
          next: {
            revalidate: 60 * 5 // 5 minutes
          }
        });

        const data = await response.json();
        return {
          chainId: parseInt(chainId),
          auctions: data.data.auctions
        };
      })
    );
    return Response.json({ auctions: allAuctions });
  } catch (error) {
    return Response.json({ error: 'Failed to fetch auctions' }, { status: 500 });
  }
} 