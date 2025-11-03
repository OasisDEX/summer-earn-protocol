'use client'

import { useMemo, useState } from 'react'

import { FinishedAuctionCard } from '@/components/FinishedAuctionCard'
import { Card, CardContent, CardHeader } from '@/components/ui/card'

type Purchase = {
  id: string
  buyer: { id: string }
  tokensPurchasedNormalized: string
  pricePerTokenNormalized: string
  totalCostNormalized: string
  timestamp: string
  marketPriceInUSDNormalized: string
  buyPriceInUSDNormalized: string
}

type Auction = {
  id: string
  auctionId: string
  ark: { address: string; commander: string }
  rewardToken: { symbol: string; decimals: number }
  buyToken: { symbol: string; decimals: number }
  startTimestamp: string
  endTimestamp: string
  purchases?: Purchase[]
}

type ChainAuctions = {
  chainId: number
  auctions: Auction[]
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

interface FinishedAuctionsViewProps {
  data: ChainAuctions[]
}

export function FinishedAuctionsView({ data }: FinishedAuctionsViewProps) {
  const allChainIds = useMemo(() => data.map((d) => d.chainId), [data])

  const [selectedChainIds, setSelectedChainIds] = useState<Set<number>>(new Set(allChainIds))
  const [selectedRewardTokens, setSelectedRewardTokens] = useState<Set<string>>(new Set())
  const [selectedBuyTokens, setSelectedBuyTokens] = useState<Set<string>>(new Set())
  const [startDate, setStartDate] = useState<string>('')
  const [endDate, setEndDate] = useState<string>('')

  const tokenOptions = useMemo(() => {
    const reward = new Set<string>()
    const buy = new Set<string>()
    for (const { auctions } of data) {
      for (const a of auctions) {
        if (a.rewardToken?.symbol) reward.add(a.rewardToken.symbol)
        if (a.buyToken?.symbol) buy.add(a.buyToken.symbol)
      }
    }
    return {
      rewardTokens: Array.from(reward).sort(),
      buyTokens: Array.from(buy).sort(),
    }
  }, [data])

  const startEpoch = useMemo(
    () => (startDate ? Math.floor(new Date(startDate).getTime() / 1000) : undefined),
    [startDate],
  )
  const endEpoch = useMemo(() => {
    if (!endDate) return undefined
    // Include full day by setting to end of the day
    const d = new Date(endDate)
    d.setHours(23, 59, 59, 999)
    return Math.floor(d.getTime() / 1000)
  }, [endDate])

  const filtered = useMemo(() => {
    const matchesToken = (a: Auction) => {
      const rewardOk =
        selectedRewardTokens.size === 0 || selectedRewardTokens.has(a.rewardToken.symbol)
      const buyOk = selectedBuyTokens.size === 0 || selectedBuyTokens.has(a.buyToken.symbol)
      return rewardOk && buyOk
    }

    const isInDateRange = (ts: number) => {
      if (startEpoch !== undefined && ts < startEpoch) return false
      if (endEpoch !== undefined && ts > endEpoch) return false
      return true
    }

    return data
      .filter((d) => selectedChainIds.has(d.chainId))
      .map(({ chainId, auctions }) => {
        const mapped = auctions
          .filter((a) => matchesToken(a))
          .map((a) => {
            const purchases = (a.purchases ?? []).filter((p) => isInDateRange(Number(p.timestamp)))
            const auctionEndInRange = isInDateRange(Number(a.endTimestamp))

            const keepAuction =
              (startEpoch === undefined && endEpoch === undefined) ||
              auctionEndInRange ||
              purchases.length > 0

            return keepAuction ? ({ ...a, purchases } as Auction) : null
          })
          .filter((x): x is Auction => x !== null)

        return { chainId, auctions: mapped }
      })
      .filter((entry) => entry.auctions.length > 0)
  }, [data, selectedChainIds, selectedRewardTokens, selectedBuyTokens, startEpoch, endEpoch])

  type SortBy = 'latestPurchase' | 'startDate' | 'endDate'
  const [sortBy, setSortBy] = useState<SortBy>('latestPurchase')

  const flattenedAndSorted = useMemo(() => {
    const flat: Array<{ chainId: number; auction: Auction; latestPurchaseTs: number | undefined }> =
      []
    for (const entry of filtered) {
      for (const a of entry.auctions) {
        const lp = (a.purchases ?? []).reduce<number | undefined>((max, p) => {
          const ts = Number(p.timestamp)
          return max === undefined || ts > max ? ts : max
        }, undefined)
        flat.push({ chainId: entry.chainId, auction: a, latestPurchaseTs: lp })
      }
    }

    const getKey = (item: { auction: Auction; latestPurchaseTs?: number }, mode: SortBy) => {
      switch (mode) {
        case 'startDate':
          return Number(item.auction.startTimestamp)
        case 'endDate':
          return Number(item.auction.endTimestamp)
        case 'latestPurchase':
        default:
          // Fallback to end date when no purchases
          return item.latestPurchaseTs ?? Number(item.auction.endTimestamp)
      }
    }

    flat.sort((a, b) => getKey(b, sortBy) - getKey(a, sortBy))
    return flat
  }, [filtered, sortBy])

  const resetFilters = () => {
    setSelectedChainIds(new Set(allChainIds))
    setSelectedRewardTokens(new Set())
    setSelectedBuyTokens(new Set())
    setStartDate('')
    setEndDate('')
  }

  return (
    <div className="space-y-6">
      <Card className="bg-white border border-gray-200 shadow-md">
        <CardHeader>
          <div className="flex items-center justify-between gap-4 flex-wrap">
            <h2 className="text-xl font-semibold text-gray-800">Filters</h2>
            <div className="flex items-center gap-2">
              <label className="text-sm font-medium text-gray-700">Sort by</label>
              <select
                className="border rounded-lg px-3 py-2 text-sm bg-white text-gray-700 border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value as SortBy)}
              >
                <option value="latestPurchase">Latest purchase</option>
                <option value="endDate">End date</option>
                <option value="startDate">Start date</option>
              </select>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            <div>
              <div className="text-sm font-medium mb-3 text-gray-700">Networks</div>
              <div className="flex flex-wrap gap-3">
                {allChainIds.map((id) => {
                  const config = getChainInfo(id)
                  return (
                    <label key={id} className="flex items-center gap-2 text-sm cursor-pointer">
                      <input
                        type="checkbox"
                        checked={selectedChainIds.has(id)}
                        onChange={(e) => {
                          setSelectedChainIds((prev) => {
                            const next = new Set(prev)
                            if (e.target.checked) next.add(id)
                            else next.delete(id)
                            return next
                          })
                        }}
                        className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                      />
                      <div className="flex items-center gap-2">
                        <div
                          className="w-3 h-3 rounded-full"
                          style={{ backgroundColor: config.color }}
                        />
                        <span className="font-medium text-gray-800">{config.name}</span>
                      </div>
                    </label>
                  )
                })}
              </div>
            </div>

            <div>
              <div className="text-sm font-medium mb-3 text-gray-700">Reward tokens</div>
              <div className="flex flex-wrap gap-3">
                {tokenOptions.rewardTokens.map((sym) => (
                  <label key={sym} className="flex items-center gap-2 text-sm cursor-pointer">
                    <input
                      type="checkbox"
                      checked={selectedRewardTokens.has(sym)}
                      onChange={(e) => {
                        setSelectedRewardTokens((prev) => {
                          const next = new Set(prev)
                          if (e.target.checked) next.add(sym)
                          else next.delete(sym)
                          return next
                        })
                      }}
                      className="rounded border-gray-300 text-green-600 focus:ring-green-500"
                    />
                    <span className="font-medium text-gray-800">{sym}</span>
                  </label>
                ))}
              </div>
            </div>

            <div>
              <div className="text-sm font-medium mb-3 text-gray-700">Buy tokens</div>
              <div className="flex flex-wrap gap-3">
                {tokenOptions.buyTokens.map((sym) => (
                  <label key={sym} className="flex items-center gap-2 text-sm cursor-pointer">
                    <input
                      type="checkbox"
                      checked={selectedBuyTokens.has(sym)}
                      onChange={(e) => {
                        setSelectedBuyTokens((prev) => {
                          const next = new Set(prev)
                          if (e.target.checked) next.add(sym)
                          else next.delete(sym)
                          return next
                        })
                      }}
                      className="rounded border-gray-300 text-purple-600 focus:ring-purple-500"
                    />
                    <span className="font-medium text-gray-800">{sym}</span>
                  </label>
                ))}
              </div>
            </div>

            <div className="md:col-span-3 grid grid-cols-1 gap-4 md:grid-cols-3 items-end">
              <div>
                <label className="text-sm font-medium mb-2 block text-gray-700">Start date</label>
                <input
                  type="date"
                  className="border rounded-lg px-3 py-2 w-full bg-white text-gray-700 border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                  value={startDate}
                  onChange={(e) => setStartDate(e.target.value)}
                />
              </div>
              <div>
                <label className="text-sm font-medium mb-2 block text-gray-700">End date</label>
                <input
                  type="date"
                  className="border rounded-lg px-3 py-2 w-full bg-white text-gray-700 border-gray-300 focus:outline-none focus:ring-offset-2"
                  value={endDate}
                  onChange={(e) => setEndDate(e.target.value)}
                />
              </div>
              <div className="flex gap-2">
                <button
                  className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg font-medium transition-colors"
                  onClick={resetFilters}
                >
                  Reset
                </button>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      <div className="text-sm text-gray-600 text-center bg-gray-50 p-3 rounded-lg">
        Showing {flattenedAndSorted.length} auctions across {filtered.length} network(s)
      </div>

      <div className="space-y-4">
        {flattenedAndSorted.map(({ chainId, auction }) => (
          <FinishedAuctionCard
            key={`${chainId}-${auction.id}`}
            auction={auction}
            chainId={chainId}
          />
        ))}
      </div>
    </div>
  )
}

export default FinishedAuctionsView
