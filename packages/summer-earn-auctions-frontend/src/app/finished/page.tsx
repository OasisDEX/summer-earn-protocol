import FinishedAuctionsView from '@/components/FinishedAuctionsView'
import { getAllFinishedAuctions } from '@/lib/getters/getFinishedAuctions'

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

export default async function FinishedAuctionsPage() {
  const auctions = (await getAllFinishedAuctions()) as ChainAuctions[]

  return (
    <div className="container py-8 space-y-6">
      <h1 className="text-3xl font-bold">Finished Auctions</h1>
      <FinishedAuctionsView data={auctions} />
    </div>
  )
}
