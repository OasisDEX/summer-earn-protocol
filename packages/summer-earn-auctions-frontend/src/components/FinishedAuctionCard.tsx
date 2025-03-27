import { Card, CardContent, CardHeader } from '@/components/ui/card'
import { ArkDisplay } from './ArkDisplay'
import { AuctionPurchase } from './AuctionPurchase'

interface FinishedAuction {
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
  purchases?: {
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

interface FinishedAuctionCardProps {
  auction: FinishedAuction
  chainId: number
}

export function FinishedAuctionCard({ auction, chainId }: FinishedAuctionCardProps) {
  return (
    <Card className="w-full">
      <CardHeader className="flex flex-row items-center justify-between">
        <div className="flex items-center gap-4">
          <ArkDisplay address={auction.ark.address} commander={auction.ark.commander} />
          <div className="text-sm text-muted-foreground">Auction #{auction.auctionId}</div>
        </div>
        <div className="flex items-center gap-2">
          <span className="text-sm text-muted-foreground">Chain ID: {chainId}</span>
        </div>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          <div className="flex justify-between text-sm">
            <span>Start: {new Date(parseInt(auction.startTimestamp) * 1000).toLocaleString()}</span>
            <span>End: {new Date(parseInt(auction.endTimestamp) * 1000).toLocaleString()}</span>
          </div>

          <div className="space-y-2">
            <h3 className="text-lg font-semibold">Purchase History</h3>
            {auction.purchases?.length === 0 ? (
              <p className="text-sm text-muted-foreground">
                No purchases were made in this auction
              </p>
            ) : (
              <div className="space-y-2">
                {auction
                  .purchases!.sort((a, b) => parseInt(b.timestamp) - parseInt(a.timestamp))
                  .map((purchase) => (
                    <AuctionPurchase
                      key={purchase.id}
                      purchase={purchase}
                      rewardToken={auction.rewardToken}
                      buyToken={auction.buyToken}
                    />
                  ))}
              </div>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
