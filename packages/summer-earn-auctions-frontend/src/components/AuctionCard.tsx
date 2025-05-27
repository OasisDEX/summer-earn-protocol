'use client'

import { Card, CardContent, CardHeader } from '@/components/ui/card'
import { CHAIN_CONFIGS } from '@/lib/config'
import { useCurrentPrice } from '@/lib/hooks/useCurrentPrice'
import { Auction } from '@/lib/types'
import { useMemo } from 'react'
import { Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { TokenAmount } from './TokenAmount'

interface AuctionCardProps {
  auction: Auction
  chainId: number
}

// Custom tooltip component
const CustomTooltip = ({ active, payload, label }: any) => {
  if (active && payload && payload.length) {
    return (
      <div className="bg-black p-2 border rounded shadow">
        <p className="text-sm text-gray-600">{`Time: ${label}`}</p>
        <p className="text-sm text-blue-600">{`Price: ${payload[0].value.toFixed(6)}`}</p>
      </div>
    )
  }
  return null
}

export function AuctionCard({ auction, chainId }: AuctionCardProps) {
  const { currentPrice, error } = useCurrentPrice(auction, chainId)
  const networkName = CHAIN_CONFIGS[chainId]?.name || `Chain ${chainId}`

  const chartData = useMemo(() => {
    const startTimestamp = parseInt(auction.startTimestamp)
    const endTimestamp = parseInt(auction.endTimestamp)
    const startPrice = parseFloat(auction.startPrice)
    const endPrice = parseFloat(auction.endPrice)

    // Calculate timestamps in milliseconds
    const now = Date.now()
    const startTimeMs = startTimestamp * 1000 // Convert to milliseconds
    const endTimeMs = endTimestamp * 1000 // Convert duration to milliseconds

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
        isNow: Math.abs(timeMs - now) < 300000, // Within 5 minutes (in milliseconds)
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
    <Card className="h-full">
      <CardHeader className="pb-2">
        <div className="flex justify-between items-start mb-4">
          <div>
            <h3 className="text-lg font-semibold">{auction.rewardToken.symbol} Auction</h3>
            <p className="text-sm text-gray-600 flex items-center gap-1">Network: {networkName}</p>
            <p className="text-sm text-gray-600 flex items-center gap-1">
              Ark:{' '}
              <button
                onClick={() => copyToClipboard(auction.ark.address)}
                className="hover:text-blue-600 transition-colors cursor-pointer"
                title="Click to copy full address"
              >
                {auction.ark.address.slice(0, 6)}...{auction.ark.address.slice(-4)}
              </button>
            </p>
            <p className="text-sm text-gray-600 flex items-center gap-1">
              Reward:{' '}
              <button
                onClick={() => copyToClipboard(auction.rewardToken.id)}
                className="hover:text-blue-600 transition-colors cursor-pointer"
                title="Click to copy full address"
              >
                {auction.rewardToken.id.slice(0, 6)}...{auction.rewardToken.id.slice(-4)}
              </button>
            </p>
          </div>
          <div className="text-right">
            <p className={`text-sm font-medium ${error ? 'text-red-500' : ''}`}>
              Current Price: {currentPrice} {auction.buyToken.symbol}
            </p>
            <p className="text-xs text-gray-600">
              Tokens Left:{' '}
              <TokenAmount
                amount={auction.tokensLeft}
                symbol={auction.rewardToken.symbol}
                decimals={auction.rewardToken.decimals}
              />
            </p>
          </div>
        </div>
      </CardHeader>
      <CardContent>
        <div className="h-40 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={chartData} margin={{ top: 5, right: 5, bottom: 20, left: 5 }}>
              <XAxis
                dataKey="time"
                angle={-45}
                textAnchor="end"
                height={40}
                interval="preserveStartEnd"
                tick={{ fontSize: 10, fill: '#4b5563' }}
              />
              <YAxis
                tickFormatter={(value) => value.toFixed(2)}
                tick={{ fontSize: 10, fill: '#4b5563' }}
              />
              <Tooltip content={<CustomTooltip />} />
              <Line
                type="monotone"
                dataKey="price"
                stroke="#2563eb"
                dot={false}
                activeDot={{
                  r: 4,
                  fill: '#2563eb',
                  stroke: 'white',
                }}
                strokeWidth={2}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>

        <div className="mt-2 text-xs text-gray-600 grid grid-cols-2 gap-1">
          <div>
            <p>Start: {startTime.toLocaleDateString()}</p>
            <p>
              Start Price: {parseFloat(auction.startPrice).toFixed(6)} {auction.buyToken.symbol}
            </p>
          </div>
          <div>
            <p>End: {endTime.toLocaleDateString()}</p>
            <p>
              End Price: {parseFloat(auction.endPrice).toFixed(6)} {auction.buyToken.symbol}
            </p>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
