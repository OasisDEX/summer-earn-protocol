import FinishedAuctionsView from '@/components/FinishedAuctionsView'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'

import { AuctionCard } from './AuctionCard'

interface Auction {
  id: string
  auctionId: string
  ark: {
    address: string
    commander: string
  }
  rewardToken: {
    id: string
    symbol: string
    decimals: number
  }
  buyToken: {
    symbol: string
    decimals: number
  }
  startTimestamp: string
  endTimestamp: string
  startPrice: string
  endPrice: string
  tokensLeft: string
}

interface ChainAuctions {
  chainId: number
  auctions: Auction[]
}

interface AuctionTabsProps {
  activeAuctions: ChainAuctions[]
  finishedAuctions: ChainAuctions[]
}

export function AuctionTabs({ activeAuctions, finishedAuctions }: AuctionTabsProps) {
  return (
    <Tabs defaultValue="active" className="w-full">
      <TabsList className="grid w-full grid-cols-2">
        <TabsTrigger value="active">Active Auctions</TabsTrigger>
        <TabsTrigger value="finished">Finished Auctions</TabsTrigger>
      </TabsList>
      <TabsContent value="active">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {activeAuctions.map(({ chainId, auctions }) =>
            auctions.map((auction) => (
              <AuctionCard key={`${chainId}-${auction.id}`} auction={auction} chainId={chainId} />
            )),
          )}
        </div>
      </TabsContent>
      <TabsContent value="finished" className="space-y-4">
        <FinishedAuctionsView data={finishedAuctions} />
      </TabsContent>
    </Tabs>
  )
}
