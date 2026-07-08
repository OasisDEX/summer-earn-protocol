'use client'

import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { formatUnits } from 'viem'

import { CHAIN_NAMES } from '../../config/chains'
import { useEnvironment } from '../../hooks/useEnvironment'
import { ChainId } from '../../types'

type ArkStatus = 'active' | 'ready-to-remove' | 'stuck-needs-sweep'

interface ArkRowData {
  address: `0x${string}`
  totalAssets: string
  withdrawableTotalAssets: string
  name: string
  depositCap: string
  isBufferArk: boolean
  status: ArkStatus
  details: { protocol?: string; pool?: string } | null
  poolBalance: string | null
  assetBalance?: string
  needsSweep: boolean
}

interface FleetOverviewData {
  address: `0x${string}`
  chainId: ChainId
  name: string
  assetSymbol: string
  assetDecimals: number
  totalAssets: string
  bufferArkAddress: `0x${string}`
  bufferArkTotalAssets: string
  bufferSharePct: number | null
  arks: ArkRowData[]
}

interface ChainOverviewData {
  chainId: ChainId
  fleets: FleetOverviewData[]
  error?: string
}

interface ApiResponse {
  environment: string
  chains: ChainOverviewData[]
  lastUpdated: number
}

interface FlatRow {
  key: string
  chainId: ChainId
  chainName: string
  fleetName: string
  assetSymbol: string
  assetDecimals: number
  fleetBufferSharePct: number | null
  ark: ArkRowData
}

type FilterKey = 'all' | 'ready-to-remove' | 'stuck-needs-sweep' | 'dust' | 'buffer'

const FILTERS: { key: FilterKey; label: string }[] = [
  { key: 'all', label: 'All' },
  { key: 'ready-to-remove', label: 'Ready to remove' },
  { key: 'stuck-needs-sweep', label: 'Stuck' },
  { key: 'dust', label: 'Has dust' },
  { key: 'buffer', label: 'Buffer arks' },
]

const STATUS_STYLES: Record<ArkStatus, string> = {
  active: 'bg-white/10 text-slate-300',
  'ready-to-remove': 'bg-emerald-500/20 text-emerald-400',
  'stuck-needs-sweep': 'bg-amber-500/20 text-amber-400',
}

function formatAmount(raw: string, decimals: number): string {
  const value = Number(formatUnits(BigInt(raw), decimals))
  return value.toLocaleString(undefined, { maximumFractionDigits: 2 })
}

async function fetchArksOverview(environment: string): Promise<ApiResponse> {
  const response = await fetch(`/api/arks-overview?environment=${environment}`)
  if (!response.ok) throw new Error('Failed to fetch arks overview')
  return response.json()
}

export default function ArksOverviewPage() {
  const { environment } = useEnvironment()
  const [filter, setFilter] = useState<FilterKey>('all')

  const { data, isLoading, error, refetch } = useQuery<ApiResponse>({
    queryKey: ['arks-overview', environment],
    queryFn: () => fetchArksOverview(environment),
  })

  const rows: FlatRow[] = useMemo(() => {
    if (!data) return []
    return data.chains.flatMap((chain) =>
      chain.fleets.flatMap((fleet) =>
        fleet.arks.map((ark) => ({
          key: `${chain.chainId}-${fleet.address}-${ark.address}`,
          chainId: chain.chainId,
          chainName: CHAIN_NAMES[chain.chainId] ?? chain.chainId,
          fleetName: fleet.name,
          assetSymbol: fleet.assetSymbol,
          assetDecimals: fleet.assetDecimals,
          fleetBufferSharePct: fleet.bufferSharePct,
          ark,
        })),
      ),
    )
  }, [data])

  const filteredRows = useMemo(() => {
    switch (filter) {
      case 'ready-to-remove':
        return rows.filter((r) => r.ark.status === 'ready-to-remove')
      case 'stuck-needs-sweep':
        return rows.filter((r) => r.ark.status === 'stuck-needs-sweep')
      case 'dust':
        return rows.filter((r) => r.ark.needsSweep)
      case 'buffer':
        return rows.filter((r) => r.ark.isBufferArk)
      default:
        return rows
    }
  }, [rows, filter])

  const summary = useMemo(
    () => ({
      readyToRemove: rows.filter((r) => r.ark.status === 'ready-to-remove').length,
      stuck: rows.filter((r) => r.ark.status === 'stuck-needs-sweep').length,
      chainErrors: data?.chains.filter((c) => c.error) ?? [],
    }),
    [rows, data],
  )

  if (isLoading) {
    return (
      <div className="text-white text-lg flex items-center justify-center h-96">
        Loading arks overview across all chains...
      </div>
    )
  }

  if (error) {
    return (
      <div className="bg-red-900/20 border border-red-500 rounded-lg p-4 text-red-400">
        Error loading arks overview: {error instanceof Error ? error.message : 'Unknown error'}
        <button
          onClick={() => refetch()}
          className="ml-4 px-4 py-2 bg-red-600 hover:bg-red-700 rounded text-white"
        >
          Retry
        </button>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-white mb-2">Arks Overview</h1>
          <p className="text-gray-400">
            Every Ark across every Fleet on every {environment} chain — deposit caps, assets, and
            removal readiness.
          </p>
          {data && (
            <p className="text-sm text-gray-500 mt-2">
              Last updated: {new Date(data.lastUpdated).toLocaleString()}
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

      {summary.chainErrors.length > 0 && (
        <div className="bg-red-900/20 border border-red-500 rounded-lg p-4 text-red-400 text-sm">
          Failed to load:{' '}
          {summary.chainErrors.map((c) => CHAIN_NAMES[c.chainId] ?? c.chainId).join(', ')}
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-gray-900 rounded-lg border border-gray-800 p-4">
          <div className="text-sm text-gray-400 mb-1">Ready to remove</div>
          <div className="text-2xl font-bold text-emerald-400">{summary.readyToRemove}</div>
        </div>
        <div className="bg-gray-900 rounded-lg border border-gray-800 p-4">
          <div className="text-sm text-gray-400 mb-1">Stuck — needs sweep</div>
          <div className="text-2xl font-bold text-amber-400">{summary.stuck}</div>
        </div>
        <div className="bg-gray-900 rounded-lg border border-gray-800 p-4">
          <div className="text-sm text-gray-400 mb-1">Total arks</div>
          <div className="text-2xl font-bold text-white">{rows.length}</div>
        </div>
      </div>

      <div className="flex gap-2">
        {FILTERS.map((f) => (
          <button
            key={f.key}
            onClick={() => setFilter(f.key)}
            className={`px-3 py-1.5 rounded-full text-sm transition-colors ${
              filter === f.key
                ? 'bg-blue-600 text-white'
                : 'bg-gray-800 text-gray-400 hover:text-white'
            }`}
          >
            {f.label}
          </button>
        ))}
      </div>

      <div className="bg-gray-900 rounded-lg border border-gray-800 overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-800 text-left text-gray-400">
              <th className="p-3">Chain</th>
              <th className="p-3">Fleet</th>
              <th className="p-3">Ark</th>
              <th className="p-3">Protocol</th>
              <th className="p-3 text-right">Deposit Cap</th>
              <th className="p-3 text-right">Total Assets</th>
              <th className="p-3 text-right">Withdrawable</th>
              <th className="p-3 text-right">Pool Balance</th>
              <th className="p-3">Status</th>
            </tr>
          </thead>
          <tbody>
            {filteredRows.map((row) => (
              <tr key={row.key} className="border-b border-gray-800/50 text-slate-300">
                <td className="p-3">{row.chainName}</td>
                <td className="p-3">{row.fleetName}</td>
                <td className="p-3">
                  {row.ark.name}
                  {row.ark.isBufferArk && (
                    <span className="ml-2 text-xs text-blue-400">
                      (buffer
                      {row.fleetBufferSharePct !== null && ` — ${row.fleetBufferSharePct}% of TVL`})
                    </span>
                  )}
                </td>
                <td className="p-3 text-gray-500">{row.ark.details?.protocol ?? '—'}</td>
                <td className="p-3 text-right">
                  {formatAmount(row.ark.depositCap, row.assetDecimals)} {row.assetSymbol}
                </td>
                <td className="p-3 text-right">
                  {formatAmount(row.ark.totalAssets, row.assetDecimals)} {row.assetSymbol}
                </td>
                <td className="p-3 text-right">
                  {formatAmount(row.ark.withdrawableTotalAssets, row.assetDecimals)}
                </td>
                <td className="p-3 text-right text-gray-500">
                  {row.ark.poolBalance !== null
                    ? formatAmount(row.ark.poolBalance, row.assetDecimals)
                    : 'N/A'}
                </td>
                <td className="p-3">
                  <span className={`px-2 py-0.5 rounded text-xs ${STATUS_STYLES[row.ark.status]}`}>
                    {row.ark.status}
                  </span>
                  {row.ark.needsSweep && (
                    <span className="ml-1 px-2 py-0.5 rounded text-xs bg-orange-500/20 text-orange-400">
                      dust
                    </span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {filteredRows.length === 0 && (
          <div className="p-8 text-center text-gray-500">No arks match this filter.</div>
        )}
      </div>
    </div>
  )
}
