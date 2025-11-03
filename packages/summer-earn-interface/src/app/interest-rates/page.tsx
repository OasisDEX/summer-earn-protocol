'use client'

import { useMemo, useState } from 'react'
import { useAccount, useSwitchChain } from 'wagmi'

import { InterestRateChart } from '../../components/InterestRateChart'
import {
  getFromTimestampForRange,
  RangeOption,
  RangeSelector,
} from '../../components/RangeSelector'
import { CHAIN_NAMES } from '../../config/chains'
import { useProducts } from '../../hooks/useInterestRates'
import { useLocalStorage } from '../../hooks/useLocalStorage'
import { useSyncWalletChain } from '../../hooks/useSyncWalletChain'
import { ChainId } from '../../types'

type TimeInterval = '10min' | 'hourly' | 'daily'

export default function InterestRatesPage() {
  const { chain } = useAccount()
  const { switchChain } = useSwitchChain()
  const [selectedProductId, setSelectedProductId] = useState<string>('')
  const [selectedInterval, setSelectedInterval] = useState<TimeInterval>('hourly')
  const [storedChain, setStoredChain] = useLocalStorage<ChainId>(
    'selectedChain',
    (chain?.id.toString() as ChainId) ?? '1',
  )

  const [range, setRange] = useState<RangeOption>('24h')
  const fromTimestamp = useMemo(() => getFromTimestampForRange(range), [range])

  const currentChainId = storedChain
  useSyncWalletChain(currentChainId)
  const { data: products, isLoading: isLoadingProducts } = useProducts(currentChainId)

  const handleChainChange = async (chainId: ChainId) => {
    try {
      await switchChain({ chainId: Number(chainId) })
      setStoredChain(chainId)
    } catch (error) {
      console.error('Failed to switch chain:', error)
    }
  }

  if (!chain) {
    return <div>Please connect your wallet</div>
  }

  if (isLoadingProducts) {
    return <div>Loading products...</div>
  }

  return (
    <div className="min-h-screen bg-black p-8">
      <div className="max-w-7xl mx-auto">
        <h1 className="text-2xl font-bold mb-6 text-white">Interest Rates</h1>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
          <div>
            <label className="block text-sm font-medium mb-2 text-gray-500">Select Chain</label>
            <select
              className="w-full p-2 border rounded bg-gray-800 text-white border-gray-700 focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
              value={currentChainId}
              onChange={(e) => handleChainChange(e.target.value as ChainId)}
            >
              {Object.entries(CHAIN_NAMES).map(([id, name]) => (
                <option key={id} value={id}>
                  {name}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium mb-2 text-gray-500">Select Product</label>
            <select
              className="w-full p-2 border rounded bg-gray-800 text-white border-gray-700 focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
              value={selectedProductId}
              onChange={(e) => setSelectedProductId(e.target.value)}
            >
              <option value="">Select a product</option>
              {products?.map((product) => (
                <option key={product.id} value={product.id}>
                  {product.name} ({product.token.symbol})
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium mb-2 text-gray-500">Time Interval</label>
            <select
              className="w-full p-2 border rounded bg-gray-800 text-white border-gray-700 focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
              value={selectedInterval}
              onChange={(e) => setSelectedInterval(e.target.value as TimeInterval)}
            >
              <option value="10min">10 Minute Intervals</option>
              <option value="hourly">Hourly</option>
              <option value="daily">Daily</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium mb-2 text-gray-500">Range</label>
            <RangeSelector value={range} onChange={setRange} />
          </div>
        </div>

        {selectedProductId && (
          <div className="bg-gray-900 rounded-lg border border-gray-800 p-4">
            <h2 className="text-xl font-semibold mb-4 text-white">Interest Rate History</h2>
            <InterestRateChart
              chainId={currentChainId}
              productId={selectedProductId}
              fromTimestamp={fromTimestamp}
              interval={selectedInterval}
            />
          </div>
        )}
      </div>
    </div>
  )
}
