import { FinishedAuctionCard } from '@/components/FinishedAuctionCard'

interface Auction {
  id: string
  auctionId: string
  ark: {
    address: string
    commander: string
  }
  rewardToken: {
    symbol: string
    decimals: number
  }
  buyToken: {
    symbol: string
    decimals: number
  }
  startTimestamp: string
  endTimestamp: string
  purchases: {
    id: string
    buyer: {
      id: string
    }
    tokensPurchasedNormalized: string
    pricePerTokenNormalized: string
    totalCostNormalized: string
    timestamp: string
    marketPriceInUSDNormalized: string
    buyPriceInUSDNormalized: string
  }[]
}

interface ChainAuctions {
  chainId: number
  auctions: Auction[]
}

async function getFinishedAuctions(): Promise<{ auctions: ChainAuctions[] }> {
  const response = await fetch(`${process.env.NEXT_PUBLIC_BASE_URL}/api/getFinishedAuctions`, {
    next: { revalidate: 60 * 15 }, // 15 minutes
  })
  return response.json()
}

export default async function FinishedAuctionsPage() {
  const { auctions } = await getFinishedAuctions()

  return (
    <div className="container py-8 space-y-6">
      <h1 className="text-3xl font-bold">Finished Auctions</h1>
      <div className="space-y-4">
        {auctions.map(({ chainId, auctions }) =>
          auctions.map((auction) => (
            <FinishedAuctionCard
              key={`${chainId}-${auction.id}`}
              auction={auction}
              chainId={chainId}
            />
          )),
        )}
      </div>
    </div>
  )
}
