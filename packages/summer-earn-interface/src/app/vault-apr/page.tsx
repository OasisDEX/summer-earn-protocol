'use client'

import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'

import { VaultAprChart } from '../../components/VaultAprChart'
import { CHAIN_NAMES } from '../../config/chains'
import { ChainId } from '../../types'

interface InterestRate {
  id: string
  date: string
  averageRate: string
  sumRates: string
  updateCount: string
}

interface VaultRates {
  id: string
  name: string | null
  symbol: string | null
  inputToken: {
    id: string
    symbol: string | null
    decimals: number
  }
  weeklyInterestRates: InterestRate[]
  dailyInterestRates: InterestRate[]
  hourlyInterestRates: InterestRate[]
}

interface VaultAprData {
  chainId: ChainId
  vaults: VaultRates[]
  latestDates: {
    weekly: string | null
    daily: string | null
    hourly: string | null
  }
}

interface ApiResponse {
  data: VaultAprData[]
  cached: boolean
  lastUpdated: number
}

async function fetchVaultAprData(): Promise<ApiResponse> {
  const response = await fetch('/api/vault-apr')
  if (!response.ok) {
    throw new Error('Failed to fetch vault APR data')
  }
  return response.json()
}

export default function VaultAprPage() {
  const [selectedChain, setSelectedChain] = useState<ChainId | 'all'>('all')
  const [selectedVault, setSelectedVault] = useState<string | null>(null)

  const { data, isLoading, error, refetch } = useQuery<ApiResponse>({
    queryKey: ['vault-apr'],
    queryFn: fetchVaultAprData,
    refetchInterval: 60 * 60 * 1000, // Refetch every hour
  })

  const filteredVaults = useMemo(() => {
    if (!data?.data) return []
    if (selectedChain === 'all') {
      return data.data.flatMap((chainData) =>
        chainData.vaults.map((vault) => ({
          ...vault,
          chainId: chainData.chainId,
          chainName: CHAIN_NAMES[chainData.chainId],
        })),
      )
    }
    const chainData = data.data.find((d) => d.chainId === selectedChain)
    return (
      chainData?.vaults.map((vault) => ({
        ...vault,
        chainId: chainData.chainId,
        chainName: CHAIN_NAMES[chainData.chainId],
      })) ?? []
    )
  }, [data, selectedChain])

  const selectedVaultData = useMemo(() => {
    if (!selectedVault) return null
    return filteredVaults.find((v) => `${v.chainId}-${v.id}` === selectedVault)
  }, [filteredVaults, selectedVault])

  if (isLoading) {
    return (
      <div className="min-h-screen bg-black p-8">
        <div className="max-w-7xl mx-auto">
          <div className="flex items-center justify-center h-96">
            <div className="text-white text-lg">Loading vault APR data...</div>
          </div>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="min-h-screen bg-black p-8">
        <div className="max-w-7xl mx-auto">
          <div className="bg-red-900/20 border border-red-500 rounded-lg p-4 text-red-400">
            Error loading vault APR data: {error instanceof Error ? error.message : 'Unknown error'}
            <button
              onClick={() => refetch()}
              className="ml-4 px-4 py-2 bg-red-600 hover:bg-red-700 rounded text-white"
            >
              Retry
            </button>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-black p-8">
      <div className="max-w-7xl mx-auto space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-white mb-2">Vault APR Analytics</h1>
            <p className="text-gray-400">
              View interest rates across all vaults with weekly, daily, and hourly granularity
            </p>
            {data && (
              <p className="text-sm text-gray-500 mt-2">
                Last updated: {new Date(data.lastUpdated).toLocaleString()}
                {data.cached && ' (cached)'}
              </p>
            )}
          </div>
          <button
            onClick={() => refetch()}
            className="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded text-white text-sm"
          >
            Refresh
          </button>
        </div>

        {/* Filters */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium mb-2 text-gray-400">Filter by Chain</label>
            <select
              className="w-full p-2 border rounded bg-gray-900 text-white border-gray-700 focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
              value={selectedChain}
              onChange={(e) => {
                setSelectedChain(e.target.value as ChainId | 'all')
                setSelectedVault(null)
              }}
            >
              <option value="all">All Chains</option>
              {Object.entries(CHAIN_NAMES).map(([id, name]) => (
                <option key={id} value={id}>
                  {name}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium mb-2 text-gray-400">Select Vault</label>
            <select
              className="w-full p-2 border rounded bg-gray-900 text-white border-gray-700 focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
              value={selectedVault || ''}
              onChange={(e) => setSelectedVault(e.target.value || null)}
            >
              <option value="">Select a vault to view chart</option>
              {filteredVaults.map((vault) => (
                <option key={`${vault.chainId}-${vault.id}`} value={`${vault.chainId}-${vault.id}`}>
                  {vault.name || vault.symbol || vault.id} ({vault.chainName}) -{' '}
                  {vault.inputToken.symbol || vault.inputToken.id}
                </option>
              ))}
            </select>
          </div>
        </div>

        {/* Stats Summary */}
        {data && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            {data.data.map((chainData) => (
              <div
                key={chainData.chainId}
                className="bg-gray-900 rounded-lg border border-gray-800 p-4"
              >
                <div className="text-sm text-gray-400 mb-1">{CHAIN_NAMES[chainData.chainId]}</div>
                <div className="text-2xl font-bold text-white">{chainData.vaults.length}</div>
                <div className="text-xs text-gray-500 mt-1">vaults</div>
                {chainData.latestDates.hourly && (
                  <div className="text-xs text-gray-500 mt-2">
                    Latest: {new Date(Number(chainData.latestDates.hourly) * 1000).toLocaleString()}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}

        {/* Chart */}
        {selectedVaultData && (
          <div className="bg-gray-900 rounded-lg border border-gray-800 p-6">
            <div className="mb-4">
              <h2 className="text-xl font-semibold text-white mb-1">
                {selectedVaultData.name || selectedVaultData.symbol || selectedVaultData.id}
              </h2>
              <div className="text-sm text-gray-400">
                Chain: {selectedVaultData.chainName} | Token:{' '}
                {selectedVaultData.inputToken.symbol || selectedVaultData.inputToken.id}
              </div>
              <div className="text-xs text-gray-500 mt-2">
                Weekly: {selectedVaultData.weeklyInterestRates.length} points | Daily:{' '}
                {selectedVaultData.dailyInterestRates.length} points | Hourly:{' '}
                {selectedVaultData.hourlyInterestRates.length} points
              </div>
            </div>
            <VaultAprChart
              weeklyRates={selectedVaultData.weeklyInterestRates}
              dailyRates={selectedVaultData.dailyInterestRates}
              hourlyRates={selectedVaultData.hourlyInterestRates}
              vaultName={selectedVaultData.name || selectedVaultData.id}
            />
          </div>
        )}

        {/* Vaults List */}
        {!selectedVaultData && (
          <div className="bg-gray-900 rounded-lg border border-gray-800 p-6">
            <h2 className="text-xl font-semibold text-white mb-4">
              Vaults ({filteredVaults.length})
            </h2>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {filteredVaults.map((vault) => {
                // Calculate 1 day average (last 24 hourly rates)
                const last24Hourly = vault.hourlyInterestRates.slice(0, 24)
                const avg1Day =
                  last24Hourly.length > 0
                    ? last24Hourly.reduce((sum, rate) => sum + Number(rate.averageRate), 0) /
                      last24Hourly.length
                    : null

                // Calculate 7 day average (last 7 daily rates)
                const last7Daily = vault.dailyInterestRates.slice(0, 7)
                const avg7Day =
                  last7Daily.length > 0
                    ? last7Daily.reduce((sum, rate) => sum + Number(rate.averageRate), 0) /
                      last7Daily.length
                    : null

                // Calculate 30 day average (last 30 daily rates)
                const last30Daily = vault.dailyInterestRates.slice(0, 30)
                const avg30Day =
                  last30Daily.length > 0
                    ? last30Daily.reduce((sum, rate) => sum + Number(rate.averageRate), 0) /
                      last30Daily.length
                    : null

                return (
                  <div
                    key={`${vault.chainId}-${vault.id}`}
                    className="bg-gray-800 rounded-lg border border-gray-700 p-4 hover:border-blue-500 cursor-pointer transition-colors"
                    onClick={() => setSelectedVault(`${vault.chainId}-${vault.id}`)}
                  >
                    <div className="text-white font-medium mb-2">
                      {vault.name || vault.symbol || vault.id.slice(0, 8) + '...'}
                    </div>
                    <div className="text-sm text-gray-400 mb-3">
                      {vault.chainName} • {vault.inputToken.symbol || 'Unknown'}
                    </div>
                    <div className="space-y-1 text-xs">
                      {avg1Day !== null && (
                        <div className="flex justify-between">
                          <span className="text-gray-500">1d Avg:</span>
                          <span className="text-green-400 font-medium">{avg1Day.toFixed(4)}%</span>
                        </div>
                      )}
                      {avg7Day !== null && (
                        <div className="flex justify-between">
                          <span className="text-gray-500">7d Avg:</span>
                          <span className="text-blue-400 font-medium">{avg7Day.toFixed(4)}%</span>
                        </div>
                      )}
                      {avg30Day !== null && (
                        <div className="flex justify-between">
                          <span className="text-gray-500">30d Avg:</span>
                          <span className="text-purple-400 font-medium">
                            {avg30Day.toFixed(4)}%
                          </span>
                        </div>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
