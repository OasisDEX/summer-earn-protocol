/**
 * Utility functions for Dutch auction price calculations
 */

export interface AuctionPriceParams {
  startPrice: number
  endPrice: number
  startTimestamp: number
  endTimestamp: number
  currentTimestamp?: number
}

export interface AuctionPriceResult {
  currentPrice: number
  progress: number
  isActive: boolean
  timeRemaining: number
  priceChange: number
  priceChangePercent: number
}

/**
 * Calculate the current price of a Dutch auction based on linear decay
 */
export function calculateAuctionPrice(params: AuctionPriceParams): AuctionPriceResult {
  const {
    startPrice,
    endPrice,
    startTimestamp,
    endTimestamp,
    currentTimestamp = Date.now(),
  } = params

  const now = currentTimestamp
  const startTimeMs = startTimestamp * 1000
  const endTimeMs = endTimestamp * 1000

  // Check if auction is active
  const isActive = now >= startTimeMs && now <= endTimeMs

  let currentPrice: number
  let progress: number
  let timeRemaining: number

  if (isActive) {
    // Calculate progress (0 to 1)
    const totalDuration = endTimeMs - startTimeMs
    const elapsed = now - startTimeMs
    progress = Math.min(elapsed / totalDuration, 1)

    // Calculate current price using linear decay
    currentPrice = startPrice - (startPrice - endPrice) * progress

    // Calculate time remaining in milliseconds
    timeRemaining = endTimeMs - now
  } else if (now < startTimeMs) {
    // Auction hasn't started yet
    currentPrice = startPrice
    progress = 0
    timeRemaining = startTimeMs - now
  } else {
    // Auction has ended
    currentPrice = endPrice
    progress = 1
    timeRemaining = 0
  }

  const priceChange = startPrice - currentPrice
  const priceChangePercent = (priceChange / startPrice) * 100

  return {
    currentPrice,
    progress,
    isActive,
    timeRemaining,
    priceChange,
    priceChangePercent,
  }
}

/**
 * Format time remaining in a human-readable format
 */
export function formatTimeRemaining(timeRemainingMs: number): string {
  const hours = Math.floor(timeRemainingMs / (1000 * 60 * 60))
  const minutes = Math.floor((timeRemainingMs % (1000 * 60 * 60)) / (1000 * 60))
  const seconds = Math.floor((timeRemainingMs % (1000 * 60)) / 1000)

  if (hours > 0) {
    return `${hours}h ${minutes}m`
  } else if (minutes > 0) {
    return `${minutes}m ${seconds}s`
  } else {
    return `${seconds}s`
  }
}

/**
 * Format price with appropriate decimal places
 */
export function formatPrice(price: number, decimals: number = 6): string {
  return price.toFixed(decimals)
}
