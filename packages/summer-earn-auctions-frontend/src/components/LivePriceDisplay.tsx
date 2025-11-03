'use client'

import { useEffect, useState } from 'react'

import { calculateAuctionPrice, formatPrice, formatTimeRemaining } from '@/utils/auctionPrice'

interface LivePriceDisplayProps {
  startPrice: string
  endPrice: string
  startTimestamp: string
  endTimestamp: string
  buyTokenSymbol: string
  className?: string
}

export function LivePriceDisplay({
  startPrice,
  endPrice,
  startTimestamp,
  endTimestamp,
  buyTokenSymbol,
  className = '',
}: LivePriceDisplayProps) {
  const [currentPrice, setCurrentPrice] = useState<number>(0)
  const [timeRemaining, setTimeRemaining] = useState<string>('')
  const [isActive, setIsActive] = useState<boolean>(false)
  const [progress, setProgress] = useState<number>(0)

  useEffect(() => {
    const updatePrice = () => {
      const result = calculateAuctionPrice({
        startPrice: parseFloat(startPrice),
        endPrice: parseFloat(endPrice),
        startTimestamp: parseInt(startTimestamp),
        endTimestamp: parseInt(endTimestamp),
      })

      setCurrentPrice(result.currentPrice)
      setIsActive(result.isActive)
      setProgress(result.progress)

      if (result.isActive) {
        setTimeRemaining(formatTimeRemaining(result.timeRemaining))
      } else if (result.timeRemaining > 0) {
        setTimeRemaining(`Starts in ${formatTimeRemaining(result.timeRemaining)}`)
      } else {
        setTimeRemaining('Ended')
      }
    }

    // Update immediately
    updatePrice()

    // Update every second for live updates
    const interval = setInterval(updatePrice, 1000)

    return () => clearInterval(interval)
  }, [startPrice, endPrice, startTimestamp, endTimestamp])

  const priceChange = parseFloat(startPrice) - currentPrice
  const priceChangePercent = (priceChange / parseFloat(startPrice)) * 100

  return (
    <div className={`space-y-2 ${className}`}>
      {/* Current Price */}
      <div className="text-center">
        <div className="text-2xl font-bold text-gray-900">
          {formatPrice(currentPrice)} {buyTokenSymbol}
        </div>
        {isActive && (
          <div className="text-sm text-gray-600">
            {priceChangePercent > 0 ? (
              <span className="text-red-600">↓ {priceChangePercent.toFixed(2)}% from start</span>
            ) : (
              <span className="text-gray-500">At start price</span>
            )}
          </div>
        )}
      </div>

      {/* Progress Bar */}
      {isActive && (
        <div className="w-full bg-gray-200 rounded-full h-2">
          <div
            className="bg-blue-600 h-2 rounded-full transition-all duration-1000 ease-out"
            style={{ width: `${progress * 100}%` }}
          />
        </div>
      )}

      {/* Time Remaining */}
      <div className="text-center">
        <div
          className={`text-sm font-medium ${
            isActive
              ? 'text-blue-600'
              : timeRemaining === 'Ended'
                ? 'text-gray-500'
                : 'text-green-600'
          }`}
        >
          {timeRemaining}
        </div>
      </div>

      {/* Price Range */}
      <div className="flex justify-between text-xs text-gray-500">
        <span>Start: {formatPrice(parseFloat(startPrice))}</span>
        <span>End: {formatPrice(parseFloat(endPrice))}</span>
      </div>
    </div>
  )
}
