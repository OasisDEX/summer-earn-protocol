'use client'

import { useTreasuryBalances, TreasuryBalance } from '@/hooks/useTreasuryBalances'
import { CHAIN_CONFIG, SupportedChainId } from '@/config/constants'
import { useSearchParams } from 'next/navigation'
import { useEffect, Suspense } from 'react'

const ChainBadge = ({ chainId }: { chainId: number }) => {
  const config = CHAIN_CONFIG[chainId as SupportedChainId]
  const colors: Record<number, string> = {
    1: 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300',
    8453: 'bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-300',
    42161: 'bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-300',
    146: 'bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-300',
    999: 'bg-pink-100 text-pink-800 dark:bg-pink-900/30 dark:text-pink-300',
  }

  return (
    <span
      className={`px-2.5 py-0.5 rounded-full text-xs font-medium ${
        colors[chainId] || 'bg-gray-100 text-gray-800'
      }`}
    >
      {config?.name || `Chain ${chainId}`}
    </span>
  )
}

function TreasuryListContent() {
  const { balances, isLoading, isError, refetch } = useTreasuryBalances()
  const searchParams = useSearchParams()

  useEffect(() => {
    if (searchParams.get('cache') === 'invalidate') {
      console.log('Cache invalidation triggered via URL')
      refetch()
    }
  }, [searchParams, refetch])

  if (isLoading) {
    return (
      <div className="flex flex-col gap-4 animate-pulse">
        {[1, 2, 3].map((i) => (
          <div
            key={i}
            className="h-24 bg-gray-100 dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700"
          />
        ))}
      </div>
    )
  }

  if (balances.length === 0 && !isError) {
    return (
      <div className="p-12 text-center bg-white dark:bg-gray-800 rounded-2xl border border-dashed border-gray-300 dark:border-gray-700">
        <p className="text-gray-500 dark:text-gray-400 text-lg">
          No token balances found in treasury wallets.
        </p>
        <button
          onClick={() => refetch()}
          className="mt-4 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm font-bold transition-colors"
        >
          Refresh Data
        </button>
      </div>
    )
  }

  if (balances.length === 0 && isError) {
    return (
      <div className="p-6 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-xl text-red-600 dark:text-red-400">
        <div className="flex items-center justify-between">
          <div>
            <p className="font-medium">Failed to fetch treasury balances.</p>
            <p className="text-sm mt-1">
              All chain requests failed or returned no data. Please check your connection and try
              again.
            </p>
          </div>
          <button
            onClick={() => refetch()}
            className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg text-sm font-bold transition-colors"
          >
            Retry
          </button>
        </div>
      </div>
    )
  }

  // Group balances by chain
  const groupedBalances = balances.reduce(
    (acc, balance) => {
      const chainId = balance.chainId
      if (!acc[chainId]) acc[chainId] = []
      acc[chainId].push(balance)
      return acc
    },
    {} as Record<number, TreasuryBalance[]>,
  )

  return (
    <div className="space-y-8">
      <div className="flex justify-end px-1">
        <button
          onClick={() => refetch()}
          className="flex items-center gap-2 px-3 py-1.5 bg-gray-100 hover:bg-gray-200 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-200 rounded-lg text-xs font-bold transition-all"
        >
          <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
            />
          </svg>
          Refresh Balances
        </button>
      </div>

      {Object.entries(groupedBalances).map(([chainId, chainBalances]) => (
        <div key={chainId} className="space-y-4">
          <div className="flex items-center gap-3 px-1">
            <h3 className="text-lg font-bold text-gray-900 dark:text-white">
              {CHAIN_CONFIG[Number(chainId) as SupportedChainId]?.name} Treasury
            </h3>
            <span className="text-xs text-gray-500 dark:text-gray-400 font-mono">
              {CHAIN_CONFIG[Number(chainId) as SupportedChainId]?.timelock.substring(0, 6)}...
              {CHAIN_CONFIG[Number(chainId) as SupportedChainId]?.timelock.substring(38)}
            </span>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {chainBalances.map((token) => (
              <div
                key={`${token.chainId}-${token.address}`}
                className="group bg-white dark:bg-gray-800 p-5 rounded-2xl border border-gray-200 dark:border-gray-700 shadow-sm hover:shadow-md transition-all duration-300 hover:border-blue-500 dark:hover:border-blue-400 flex items-center gap-4"
              >
                <div className="relative w-12 h-12 flex-shrink-0 bg-gray-50 dark:bg-gray-900 rounded-full flex items-center justify-center border border-gray-100 dark:border-gray-800">
                  {token.logoURI ? (
                    <img
                      src={token.logoURI}
                      alt={token.symbol}
                      className="w-10 h-10 rounded-full object-contain"
                      onError={(e) => {
                        ;(e.target as HTMLImageElement).style.display = 'none'
                        ;(e.target as HTMLImageElement).parentElement!.innerHTML =
                          `<div class="text-xs font-bold text-gray-400">${token.symbol.substring(0, 2)}</div>`
                      }}
                    />
                  ) : (
                    <div className="text-xs font-bold text-gray-400">
                      {token.symbol.substring(0, 2)}
                    </div>
                  )}
                </div>

                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between gap-2">
                    <h4 className="font-bold text-gray-900 dark:text-white truncate">
                      {token.symbol}
                    </h4>
                    <ChainBadge chainId={token.chainId} />
                  </div>
                  <p className="text-xs text-gray-500 dark:text-gray-400 truncate mb-1">
                    {token.name}
                  </p>
                  <div className="flex items-baseline gap-1">
                    <span className="text-xl font-black text-gray-900 dark:text-white tabular-nums">
                      {Number(token.formattedBalance).toLocaleString(undefined, {
                        maximumFractionDigits: 4,
                      })}
                    </span>
                    <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">
                      {token.symbol}
                    </span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  )
}

export function TreasuryList() {
  return (
    <Suspense
      fallback={<div className="animate-pulse h-64 bg-gray-100 dark:bg-gray-800 rounded-2xl" />}
    >
      <TreasuryListContent />
    </Suspense>
  )
}
