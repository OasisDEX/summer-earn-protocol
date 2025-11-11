'use client'

import { useEffect, useState } from 'react'
import { formatUnits } from 'viem'

import { Auction } from '@/lib/types'

export function useCurrentPrice(auction: Auction, chainId: number) {
  const [currentPrice, setCurrentPrice] = useState<string>()
  const [error, setError] = useState(false)

  useEffect(() => {
    const fetchPrice = async () => {
      try {
        const response = await fetch('/api/getCurrentPrice', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            chainId,
            arkAddress: auction.ark.address,
            rewardAddress: auction.rewardToken.id,
            raftAddress: auction.raft,
          }),
        })

        const data = await response.json()
        if (data.error) throw new Error(data.error)
        const formattedPrice = formatUnits(data.currentPrice, auction.buyToken.decimals)
        setCurrentPrice(formattedPrice)
        setError(false)
      } catch (err) {
        console.error(err)
        setError(true)
      }
    }

    fetchPrice()
    const interval = setInterval(fetchPrice, 15000)
    return () => clearInterval(interval)
  }, [auction.id, chainId])

  return { currentPrice, error }
}
