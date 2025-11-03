'use client'

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

// Simple chain configuration
const getChainInfo = (chainId: number) => {
  switch (chainId) {
    case 1:
      return { name: 'Ethereum', color: '#627EEA' }
    case 8453:
      return { name: 'Base', color: '#0052FF' }
    case 42161:
      return { name: 'Arbitrum', color: '#28A0F0' }
    case 146:
      return { name: 'Sonic', color: '#FF6B35' }
    default:
      return { name: `Chain ${chainId}`, color: '#666' }
  }
}

interface FinishedAuctionCardProps {
  auction: FinishedAuction
  chainId: number
}

export function FinishedAuctionCard({ auction, chainId }: FinishedAuctionCardProps) {
  const chainInfo = getChainInfo(chainId)
  const networkName = chainInfo.name
  const networkColor = chainInfo.color

  return (
    <Card className="w-full bg-white border border-gray-600 shadow-md hover:shadow-lg transition-all duration-300">
      <CardHeader className="flex flex-row items-center justify-between bg-gray-50 border-b">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-3">
            <div className="w-4 h-4 rounded-full" style={{ backgroundColor: networkColor }} />
            <ArkDisplay address={auction.ark.address} commander={auction.ark.commander} />
          </div>
          <div className="text-sm text-gray-600 bg-white px-3 py-1 rounded-full border">
            Auction #{auction.auctionId}
          </div>
          <div className="text-sm text-gray-600 bg-white px-3 py-1 rounded-full border">
            {networkName}
          </div>
        </div>
        <div className="flex items-center gap-2">
          <span className="text-sm text-gray-500 bg-gray-100 px-2 py-1 rounded">
            Chain ID: {chainId}
          </span>
        </div>
      </CardHeader>
      <CardContent className="p-6">
        <div className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="bg-blue-50 p-4 rounded-lg border border-blue-200">
              <h4 className="font-medium text-blue-800 mb-2">Start Time</h4>
              <p className="text-blue-700">
                {new Date(parseInt(auction.startTimestamp) * 1000).toLocaleString()}
              </p>
            </div>
            <div className="bg-green-50 p-4 rounded-lg border border-green-200">
              <h4 className="font-medium text-green-800 mb-2">End Time</h4>
              <p className="text-green-700">
                {new Date(parseInt(auction.endTimestamp) * 1000).toLocaleString()}
              </p>
            </div>
          </div>

          <div className="space-y-4">
            <div className="flex items-center gap-3">
              <h3 className="text-lg font-semibold text-gray-800">Purchase History</h3>
              <div className="bg-gray-100 px-3 py-1 rounded-full text-sm text-gray-600">
                {auction.purchases?.length || 0} purchases
              </div>
            </div>

            {auction.purchases?.length === 0 ? (
              <div className="bg-gray-50 p-6 rounded-lg text-center">
                <p className="text-gray-600">No purchases were made in this auction</p>
              </div>
            ) : (
              <div className="space-y-3">
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
