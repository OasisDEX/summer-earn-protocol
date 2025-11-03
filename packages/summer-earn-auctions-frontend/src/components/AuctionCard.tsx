'use client'

import { useMemo } from 'react'
import { Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'

import { Card, CardContent, CardHeader } from '@/components/ui/card'

import { LivePriceDisplay } from './LivePriceDisplay'
import { TokenAmount } from './TokenAmount'

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

interface AuctionCardProps {
  auction: Auction
  chainId: number
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

// Custom tooltip component
const CustomTooltip = ({ active, payload, label }: any) => {
  if (active && payload && payload.length) {
    return (
      <div className="bg-white p-3 border border-gray-200 rounded-lg shadow-lg">
        <p className="font-medium text-gray-800">{`Time: ${label}`}</p>
        <p className="text-blue-600">{`Price: ${payload[0].value.toFixed(6)}`}</p>
      </div>
    )
  }
  return null
}

export function AuctionCard({ auction, chainId }: AuctionCardProps) {
  const chainInfo = getChainInfo(chainId)
  const networkName = chainInfo.name
  const networkColor = chainInfo.color

  const chartData = useMemo(() => {
    const startTimestamp = parseInt(auction.startTimestamp)
    const endTimestamp = parseInt(auction.endTimestamp)
    const startPrice = parseFloat(auction.startPrice)
    const endPrice = parseFloat(auction.endPrice)

    // Calculate timestamps in milliseconds
    const now = Date.now()
    const startTimeMs = startTimestamp * 1000
    const endTimeMs = endTimestamp * 1000

    const points = []
    const numPoints = 20

    for (let i = 0; i <= numPoints; i++) {
      const timeMs = startTimeMs + ((endTimeMs - startTimeMs) * i) / numPoints
      const progress = i / numPoints
      const price = startPrice - (startPrice - endPrice) * progress

      // Format the date for display
      const date = new Date(timeMs)
      const formattedTime = new Intl.DateTimeFormat('en-US', {
        month: 'short',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      }).format(date)

      points.push({
        time: formattedTime,
        timestamp: timeMs,
        price,
        isNow: Math.abs(timeMs - now) < 300000, // Within 5 minutes
      })
    }
    return points
  }, [auction])

  // Copy address to clipboard
  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text)
  }

  // Format start and end times
  const startTime = new Date(parseInt(auction.startTimestamp) * 1000)
  const endTime = new Date(parseInt(auction.endTimestamp) * 1000)

  return (
    <Card className="h-full bg-white border border-gray-200 shadow-md hover:shadow-lg transition-all duration-300 overflow-hidden">
      <CardHeader className="pb-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-3 h-3 rounded-full" style={{ backgroundColor: networkColor }} />
            <h3 className="text-lg font-semibold text-gray-800">
              {auction.rewardToken.symbol} Auction
            </h3>
          </div>
          <div className="text-sm text-gray-600 bg-gray-100 px-2 py-1 rounded-full">
            {networkName}
          </div>
        </div>

        <div className="space-y-2">
          <div className="flex items-center gap-2 text-sm">
            <span className="text-gray-600">Ark:</span>
            <button
              className="text-blue-600 hover:text-blue-800 font-mono text-xs bg-blue-50 px-2 py-1 rounded hover:bg-blue-100 transition-colors"
              onClick={() => copyToClipboard(auction.ark.address)}
            >
              {auction.ark.address.slice(0, 6)}...{auction.ark.address.slice(-4)}
            </button>
          </div>

          <div className="flex items-center gap-2 text-sm">
            <span className="text-gray-600">Reward Token:</span>
            <button
              className="text-green-600 hover:text-green-800 font-mono text-xs bg-green-50 px-2 py-1 rounded hover:bg-green-100 transition-colors"
              onClick={() => copyToClipboard(auction.rewardToken.id)}
            >
              {auction.rewardToken.id.slice(0, 6)}...{auction.rewardToken.id.slice(-4)}
            </button>
          </div>
        </div>
      </CardHeader>

      <CardContent className="space-y-4">
        <LivePriceDisplay
          startPrice={auction.startPrice}
          endPrice={auction.endPrice}
          startTimestamp={auction.startTimestamp}
          endTimestamp={auction.endTimestamp}
          buyTokenSymbol={auction.buyToken.symbol}
          className="bg-blue-50 p-4 rounded-lg border border-blue-200"
        />

        <div className="bg-green-50 p-4 rounded-lg border border-green-200">
          <div className="text-center">
            <TokenAmount
              amount={auction.tokensLeft}
              symbol={auction.rewardToken.symbol}
              decimals={auction.rewardToken.decimals}
            />
            <p className="text-sm text-green-600">Tokens Remaining</p>
          </div>
        </div>

        <div className="h-40 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={chartData} margin={{ top: 5, right: 5, bottom: 20, left: 5 }}>
              <XAxis
                dataKey="time"
                angle={-45}
                textAnchor="end"
                height={40}
                interval="preserveStartEnd"
                tick={{ fontSize: 10, fill: '#374151' }}
              />
              <YAxis
                tickFormatter={(value) => value.toFixed(2)}
                tick={{ fontSize: 10, fill: '#374151' }}
              />
              <Tooltip content={<CustomTooltip />} />
              <Line
                type="monotone"
                dataKey="price"
                stroke={networkColor}
                dot={false}
                activeDot={{
                  r: 4,
                  fill: networkColor,
                  stroke: 'white',
                  strokeWidth: 2,
                }}
                strokeWidth={2}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>

        <div className="grid grid-cols-2 gap-4 text-sm">
          <div className="bg-gray-50 p-3 rounded-lg">
            <p className="font-medium text-gray-700">Start</p>
            <p className="text-gray-600">{startTime.toLocaleDateString()}</p>
            <p className="text-gray-500 text-xs">
              {parseFloat(auction.startPrice).toFixed(6)} {auction.buyToken.symbol}
            </p>
          </div>
          <div className="bg-gray-50 p-3 rounded-lg">
            <p className="font-medium text-gray-700">End</p>
            <p className="text-gray-600">{endTime.toLocaleDateString()}</p>
            <p className="text-gray-500 text-xs">
              {parseFloat(auction.endPrice).toFixed(6)} {auction.buyToken.symbol}
            </p>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
