'use client'

import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { formatUnits } from 'viem'

import {
  Badge,
  Button,
  ErrorState,
  PageHeader,
  Table,
  TableContainer,
  TBody,
  Td,
  Th,
  THead,
  Tr,
} from '../../components/ui'
import { CHAIN_BLOCK_EXPLORERS, CHAIN_NAMES } from '../../config/chains'
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
  fleetAddress: `0x${string}`
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

const STATUS_TONE: Record<ArkStatus, 'neutral' | 'success' | 'warning'> = {
  active: 'neutral',
  'ready-to-remove': 'success',
  'stuck-needs-sweep': 'warning',
}

// Validated categorical palette (dark-mode steps, dataviz skill's reference palette),
// used to visually group rows by fleet. CVD-safe fixed order; identity is never carried
// by color alone since the fleet name is always shown as a direct label.
const FLEET_PALETTE = [
  '#3987e5', // blue
  '#199e70', // aqua
  '#c98500', // yellow
  '#008300', // green
  '#9085e9', // violet
  '#e66767', // red
  '#d55181', // magenta
  '#d95926', // orange
]

const MAX_UINT256 = 2n ** 256n - 1n

function fleetKeyFor(chainId: ChainId, fleetAddress: string): string {
  return `${chainId}-${fleetAddress}`
}

function formatAmount(raw: string, decimals: number): string {
  const value = Number(formatUnits(BigInt(raw), decimals))
  return value.toLocaleString(undefined, { maximumFractionDigits: 2 })
}

function formatCap(raw: string, decimals: number, symbol: string): string {
  if (BigInt(raw) === MAX_UINT256) return 'MAX'
  return `${formatAmount(raw, decimals)} ${symbol}`
}

// Unrounded, full-precision amount — for tooltips where a rounded display would
// misleadingly show "0" (e.g. dust balances far below the 2-decimal display threshold).
function formatExact(raw: string, decimals: number): string {
  return formatUnits(BigInt(raw), decimals)
}

function explorerAddressUrl(chainId: ChainId, address: string): string | null {
  const base = CHAIN_BLOCK_EXPLORERS[chainId]
  return base ? `${base}/address/${address}` : null
}

async function fetchArksOverview(environment: string): Promise<ApiResponse> {
  const response = await fetch(`/api/arks-overview?environment=${environment}`)
  if (!response.ok) throw new Error('Failed to fetch arks overview')
  return response.json()
}

export default function ArksOverviewPage() {
  const { environment } = useEnvironment()
  const [filter, setFilter] = useState<FilterKey>('all')
  const [selectedFleet, setSelectedFleet] = useState<string>('all')

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
          fleetAddress: fleet.address,
          fleetName: fleet.name,
          assetSymbol: fleet.assetSymbol,
          assetDecimals: fleet.assetDecimals,
          fleetBufferSharePct: fleet.bufferSharePct,
          ark,
        })),
      ),
    )
  }, [data])

  // Distinct fleets in first-appearance order, for the fleet filter dropdown.
  const fleetOptions = useMemo(() => {
    const seen = new Map<string, string>()
    for (const r of rows) {
      const key = fleetKeyFor(r.chainId, r.fleetAddress)
      if (!seen.has(key)) {
        seen.set(key, `${r.chainName} — ${r.fleetName}`)
      }
    }
    return Array.from(seen.entries()).map(([key, label]) => ({ key, label }))
  }, [rows])

  // One palette color per distinct fleet, assigned in fixed first-appearance order.
  // Cycles past 8 fleets — acceptable here because the fleet name is always shown as
  // text alongside the color, so color is a supplementary grouping cue, not the sole
  // identity channel.
  const fleetColorByKey = useMemo(() => {
    const map = new Map<string, string>()
    let index = 0
    for (const r of rows) {
      const key = fleetKeyFor(r.chainId, r.fleetAddress)
      if (!map.has(key)) {
        map.set(key, FLEET_PALETTE[index % FLEET_PALETTE.length])
        index += 1
      }
    }
    return map
  }, [rows])

  const filteredRows = useMemo(() => {
    let result = rows
    if (selectedFleet !== 'all') {
      result = result.filter((r) => fleetKeyFor(r.chainId, r.fleetAddress) === selectedFleet)
    }
    switch (filter) {
      case 'ready-to-remove':
        return result.filter((r) => r.ark.status === 'ready-to-remove')
      case 'stuck-needs-sweep':
        return result.filter((r) => r.ark.status === 'stuck-needs-sweep')
      case 'dust':
        return result.filter((r) => r.ark.needsSweep)
      case 'buffer':
        return result.filter((r) => r.ark.isBufferArk)
      default:
        return result
    }
  }, [rows, filter, selectedFleet])

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
      <div className="text-on-surface text-lg flex items-center justify-center h-96">
        Loading arks overview across all chains…
      </div>
    )
  }

  if (error) {
    return (
      <ErrorState
        title="Error loading arks overview"
        error={error instanceof Error ? error : { message: 'Unknown error' }}
        action={
          <Button variant="danger" onClick={() => refetch()}>
            Retry
          </Button>
        }
      />
    )
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Arks Overview"
        description={
          <>
            Every Ark across every Fleet on every {environment} chain — deposit caps, assets, and
            removal readiness.
            {data && (
              <span className="block mt-1.5 text-xs text-on-surface-variant/80">
                Last updated: {new Date(data.lastUpdated).toLocaleString()}
              </span>
            )}
          </>
        }
        actions={
          <Button variant="primary" onClick={() => refetch()}>
            Refresh
          </Button>
        }
      />

      {summary.chainErrors.length > 0 && (
        <div className="bg-error/10 border border-error/20 rounded-lg p-4 text-error text-sm">
          Failed to load:{' '}
          {summary.chainErrors.map((c) => CHAIN_NAMES[c.chainId] ?? c.chainId).join(', ')}
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-surface-container-high border border-white/10 rounded-lg p-4">
          <div className="text-sm text-on-surface-variant mb-1">Ready to remove</div>
          <div className="text-2xl font-bold text-success tabular-nums">
            {summary.readyToRemove}
          </div>
        </div>
        <div className="bg-surface-container-high border border-white/10 rounded-lg p-4">
          <div className="text-sm text-on-surface-variant mb-1">Stuck — needs sweep</div>
          <div className="text-2xl font-bold text-warning tabular-nums">{summary.stuck}</div>
        </div>
        <div className="bg-surface-container-high border border-white/10 rounded-lg p-4">
          <div className="text-sm text-on-surface-variant mb-1">Total arks</div>
          <div className="text-2xl font-bold text-on-surface tabular-nums">{rows.length}</div>
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        {FILTERS.map((f) => (
          <button
            key={f.key}
            onClick={() => setFilter(f.key)}
            className={`px-3 py-1.5 rounded-full text-sm transition-colors ${
              filter === f.key
                ? 'bg-primary text-on-primary'
                : 'bg-white/5 text-on-surface-variant hover:text-on-surface'
            }`}
          >
            {f.label}
          </button>
        ))}

        <select
          value={selectedFleet}
          onChange={(e) => setSelectedFleet(e.target.value)}
          className="ml-2 px-3 py-1.5 rounded-full text-sm bg-white/5 text-on-surface-variant border border-white/10 focus:border-primary/60 focus:ring-1 focus:ring-primary/40"
        >
          <option value="all">All fleets</option>
          {fleetOptions.map((f) => (
            <option key={f.key} value={f.key}>
              {f.label}
            </option>
          ))}
        </select>
      </div>

      <TableContainer>
        <Table>
          <THead>
            <Tr className="border-b border-white/10">
              <Th>Chain</Th>
              <Th>Fleet</Th>
              <Th>Ark</Th>
              <Th>Protocol</Th>
              <Th numeric>Deposit Cap</Th>
              <Th numeric>Total Assets</Th>
              <Th numeric>Withdrawable</Th>
              <Th numeric>Pool Balance</Th>
              <Th>Status</Th>
            </Tr>
          </THead>
          <TBody>
            {filteredRows.map((row) => {
              const fleetKey = fleetKeyFor(row.chainId, row.fleetAddress)
              const fleetColor = fleetColorByKey.get(fleetKey) ?? '#64748b'
              return (
                <Tr
                  key={row.key}
                  className="text-on-surface-variant"
                  style={{ backgroundColor: `${fleetColor}1a` }}
                >
                  <Td>{row.chainName}</Td>
                  <Td>
                    <span
                      className="inline-block w-2 h-2 rounded-full mr-2 align-middle"
                      style={{ backgroundColor: fleetColor }}
                      aria-hidden="true"
                    />
                    {row.fleetName}
                  </Td>
                  <Td>
                    {(() => {
                      const explorerUrl = explorerAddressUrl(row.chainId, row.ark.address)
                      return explorerUrl ? (
                        <a
                          href={explorerUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-on-surface hover:text-primary hover:underline"
                          title={row.ark.address}
                        >
                          {row.ark.name}
                        </a>
                      ) : (
                        row.ark.name
                      )
                    })()}
                    {row.ark.isBufferArk && (
                      <span className="ml-2 text-xs text-info">
                        (buffer
                        {row.fleetBufferSharePct !== null &&
                          ` — ${row.fleetBufferSharePct}% of TVL`}
                        )
                      </span>
                    )}
                  </Td>
                  <Td className="text-on-surface-variant/80">{row.ark.details?.protocol ?? '—'}</Td>
                  <Td numeric>
                    {formatCap(row.ark.depositCap, row.assetDecimals, row.assetSymbol)}
                  </Td>
                  <Td numeric>
                    {formatAmount(row.ark.totalAssets, row.assetDecimals)} {row.assetSymbol}
                  </Td>
                  <Td numeric>
                    {formatAmount(row.ark.withdrawableTotalAssets, row.assetDecimals)}
                  </Td>
                  <Td numeric className="text-on-surface-variant/80">
                    {row.ark.poolBalance !== null
                      ? formatAmount(row.ark.poolBalance, row.assetDecimals)
                      : 'N/A'}
                  </Td>
                  <Td>
                    <Badge tone={STATUS_TONE[row.ark.status]} size="sm">
                      {row.ark.status}
                    </Badge>
                    {row.ark.needsSweep && (
                      <Badge
                        tone="warning"
                        size="sm"
                        className="ml-1 cursor-help"
                        title={`Idle balance: ${formatExact(row.ark.assetBalance ?? '0', row.assetDecimals)} ${row.assetSymbol}`}
                      >
                        dust
                      </Badge>
                    )}
                  </Td>
                </Tr>
              )
            })}
          </TBody>
        </Table>
        {filteredRows.length === 0 && (
          <div className="p-8 text-center text-on-surface-variant">No arks match this filter.</div>
        )}
      </TableContainer>
    </div>
  )
}
