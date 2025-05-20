'use client'

import { useState } from 'react'
import { useAccount, useSwitchChain } from 'wagmi'
import { InterestRateChart } from '../../components/InterestRateChart'
import { CHAIN_NAMES } from '../../config/chains'
import { useProducts } from '../../hooks/useInterestRates'
import { ChainId } from '../../types'

type TimeInterval = '10min' | 'hourly' | 'daily'

export default function InterestRatesPage() {
  const { chain } = useAccount()
  const { switchChain } = useSwitchChain()
  const [selectedProductId, setSelectedProductId] = useState<string>('')
  const [selectedInterval, setSelectedInterval] = useState<TimeInterval>('daily')

  // Get timestamp for 24 hours ago
  const fromTimestamp = Math.floor(Date.now() / 1000) - 24 * 60 * 60

  const { data: products, isLoading: isLoadingProducts } = useProducts(
    (chain?.id.toString() as ChainId) ?? '1',
  )

  const handleChainChange = async (chainId: ChainId) => {
    try {
      await switchChain({ chainId: Number(chainId) })
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
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-2xl font-bold mb-6 text-gray-500">Interest Rates</h1>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
        <div>
          <label className="block text-sm font-medium mb-2 text-gray-500">Select Chain</label>
          <select
            className="w-full p-2 border rounded bg-white text-gray-900 border-gray-300 focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
            value={chain.id.toString()}
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
            className="w-full p-2 border rounded bg-white text-gray-900 border-gray-300 focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
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
            className="w-full p-2 border rounded bg-white text-gray-900 border-gray-300 focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
            value={selectedInterval}
            onChange={(e) => setSelectedInterval(e.target.value as TimeInterval)}
          >
            <option value="10min">10 Minute Intervals</option>
            <option value="hourly">Hourly</option>
            <option value="daily">Daily</option>
          </select>
        </div>
      </div>

      {selectedProductId && (
        <div className="bg-white rounded-lg shadow p-4">
          <h2 className="text-xl font-semibold mb-4 text-gray-900">24h Interest Rate History</h2>
          <InterestRateChart
            chainId={chain.id.toString() as ChainId}
            productId={selectedProductId}
            fromTimestamp={fromTimestamp}
            interval={selectedInterval}
          />
        </div>
      )}
    </div>
  )
}
