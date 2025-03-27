import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Auction } from '@/lib/types'
import { AuctionCard } from './AuctionCard'
import { FinishedAuctionCard } from './FinishedAuctionCard'

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
      <TabsContent value="active" className="space-y-4">
        {activeAuctions.map(({ chainId, auctions }) =>
          auctions.map((auction) => (
            <AuctionCard key={`${chainId}-${auction.id}`} auction={auction} chainId={chainId} />
          )),
        )}
      </TabsContent>
      <TabsContent value="finished" className="space-y-4">
        {finishedAuctions.map(({ chainId, auctions }) =>
          auctions
            .sort((a, b) => parseInt(b.purchases[0].timestamp) - parseInt(a.purchases[0].timestamp))
            .map((auction) => (
              <FinishedAuctionCard
                key={`${chainId}-${auction.id}`}
                auction={auction}
                chainId={chainId}
              />
            )),
        )}
      </TabsContent>
    </Tabs>
  )
}
