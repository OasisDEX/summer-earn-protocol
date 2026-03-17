'use client'

import { useMemo, useState } from 'react'
import Link from 'next/link'

import type { WalletSnapshot } from '@/lib/vesting-logic'
import { formatDecimalOutput } from '@/utils/decimals'

import { ProgressBar } from './ProgressBar'

function StatCard({
  label,
  value,
  suffix,
  highlight,
}: {
  label: string
  value: string
  suffix?: string
  highlight?: boolean
}) {
  return (
    <div
      className={`glass rounded-xl p-4 text-left space-y-1 ${highlight ? 'border-primary/30' : ''}`}
    >
      <div className="text-[10px] uppercase tracking-wide font-bold text-slate-500">{label}</div>
      <div className="text-2xl font-bold text-white tracking-tight">
        {value} <span className="text-slate-500 text-sm font-normal">{suffix}</span>
      </div>
    </div>
  )
}

function SortableHeader({
  label,
  sortKey,
  onClick,
  currentSort,
}: {
  label: string
  sortKey: keyof WalletSnapshot
  onClick: (key: keyof WalletSnapshot) => void
  currentSort: { key: string; direction: 'asc' | 'desc' } | null
}) {
  return (
    <th
      className="px-3 py-3 text-right border-b border-white/10 cursor-pointer hover:bg-white/5 transition-colors group select-none"
      onClick={() => onClick(sortKey)}
    >
      <div className="flex items-center justify-end gap-1 text-slate-400">
        {label}
        <span className="text-slate-600 text-[10px]">
          {currentSort?.key === sortKey ? (currentSort.direction === 'asc' ? '▲' : '▼') : '↕'}
        </span>
      </div>
    </th>
  )
}

export default function VestingBatchTable({
  initialSnapshots,
  chainId,
}: {
  initialSnapshots: any[]
  chainId?: string
}) {
  // Convert stringified BigInts back to BigInt for sorting/math
  const snapshots = useMemo(() => {
    return initialSnapshots.map((s) => ({
      ...s,
      totalPlanned: BigInt(s.totalPlanned || 0),
      vested: BigInt(s.vested || 0),
      releasable: BigInt(s.releasable || 0),
      unvested: BigInt(s.unvested || 0),
      summerBalance: BigInt(s.summerBalance || 0),
      xSummerBalance: BigInt(s.xSummerBalance || 0),
      stakingBalance: BigInt(s.stakingBalance || 0),
      governanceRewardsBalance: BigInt(s.governanceRewardsBalance || 0),
      stakes: (s.stakes || []).map((k: any) => ({ ...k, amount: BigInt(k.amount || 0) })),
    })) as WalletSnapshot[]
  }, [initialSnapshots])

  const [sortConfig, setSortConfig] = useState<{
    key: keyof WalletSnapshot
    direction: 'asc' | 'desc'
  } | null>(null)
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'completed'>('all')
  const [searchQuery, setSearchQuery] = useState('')

  const filteredAndSortedSnapshots = useMemo(() => {
    let data = snapshots

    // 1. Status Filter
    if (statusFilter !== 'all') {
      data = data.filter((s) => {
        const isCompleted = s.totalPlanned > BigInt(0) && s.vested >= s.totalPlanned
        return statusFilter === 'completed' ? isCompleted : !isCompleted
      })
    }

    // 2. Search
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase()
      data = data.filter(
        (s) =>
          s.codename?.toLowerCase().includes(q) ||
          s.owner?.toLowerCase().includes(q) ||
          s.vestingWallet?.toLowerCase().includes(q),
      )
    }

    // 3. Sort
    if (sortConfig) {
      data = [...data].sort((a, b) => {
        const valA = a[sortConfig.key] ?? 0
        const valB = b[sortConfig.key] ?? 0

        if (typeof valA === 'bigint' && typeof valB === 'bigint') {
          return sortConfig.direction === 'asc'
            ? valA < valB
              ? -1
              : valA > valB
                ? 1
                : 0
            : valA > valB
              ? -1
              : valA < valB
                ? 1
                : 0
        }
        if (typeof valA === 'number' && typeof valB === 'number') {
          return sortConfig.direction === 'asc' ? valA - valB : valB - valA
        }
        return 0
      })
    }
    return data
  }, [snapshots, sortConfig, statusFilter, searchQuery])

  const summaryTotals = useMemo(() => {
    return snapshots.reduce(
      (acc, s) => {
        acc.totalPlanned += s.totalPlanned || 0n
        acc.vested += s.vested || 0n
        acc.unvested += s.unvested || 0n
        const current =
          (s.unvested || 0n) +
          (s.releasable || 0n) +
          (s.summerBalance || 0n) +
          (s.xSummerBalance || 0n)
        const delta = current - (s.totalPlanned || 0n)
        if (delta < 0n) acc.totalDeficit += -delta
        return acc
      },
      { totalPlanned: 0n, vested: 0n, unvested: 0n, totalDeficit: 0n },
    )
  }, [snapshots])

  const deficitCount = useMemo(
    () =>
      snapshots.filter((s) => {
        const current =
          (s.unvested || 0n) +
          (s.releasable || 0n) +
          (s.summerBalance || 0n) +
          (s.xSummerBalance || 0n)
        return current < (s.totalPlanned || 0n)
      }).length,
    [snapshots],
  )

  const uniqueRecipients = useMemo(() => new Set(snapshots.map((s) => s.owner)).size, [snapshots])

  const handleSort = (key: keyof WalletSnapshot) => {
    setSortConfig((current) => ({
      key,
      direction: current?.key === key && current.direction === 'asc' ? 'desc' : 'asc',
    }))
  }

  return (
    <>
      <div className="glass rounded-2xl p-4 mb-6">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4">
          <StatCard
            label="Total Planned"
            value={formatDecimalOutput(summaryTotals.totalPlanned, 18)}
            suffix="SUMR"
            highlight
          />
          <StatCard
            label="Vested Total"
            value={formatDecimalOutput(summaryTotals.vested, 18)}
            suffix="SUMR"
          />
          <StatCard
            label="Unvested Future"
            value={formatDecimalOutput(summaryTotals.unvested, 18)}
            suffix="SUMR"
          />
          <StatCard label="Unique Recipients" value={String(uniqueRecipients)} suffix="wallets" />
          <StatCard
            label="Deficit Wallets"
            value={`${deficitCount}`}
            suffix={`/ ${snapshots.length} (${formatDecimalOutput(summaryTotals.totalDeficit, 18)} SUMR)`}
            highlight={deficitCount > 0}
          />
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-4 mb-6">
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Search wallet or codename..."
          className="px-4 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/50 w-full max-w-xs"
        />
        <div className="flex gap-2">
          {(['all', 'active', 'completed'] as const).map((s) => (
            <button
              key={s}
              onClick={() => setStatusFilter(s)}
              className={`px-4 py-2 rounded-xl font-bold text-sm transition-all ${
                statusFilter === s
                  ? 'bg-primary text-white border border-primary/50'
                  : 'bg-white/5 text-slate-400 border border-white/5 hover:text-slate-300'
              }`}
            >
              {s === 'all' ? 'All' : s === 'active' ? 'Active' : 'Completed'}
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      <div className="glass rounded-2xl overflow-x-auto w-full relative shadow-2xl">
        <table className="w-full table-auto text-xs md:text-sm text-slate-200 whitespace-nowrap">
          <thead className="bg-charcoal-800/90 sticky top-0 z-20 backdrop-blur-md">
            <tr>
              <th className="px-3 py-3 text-left sticky left-0 bg-charcoal-800/95 z-30 shadow-[4px_0_8px_-4px_rgba(0,0,0,0.3)] border-b border-white/10">
                Codename
              </th>
              <th className="px-3 py-3 text-left border-b border-white/10 text-slate-400">
                Wallet / Owner
              </th>
              <SortableHeader
                label="Planned"
                sortKey="totalPlanned"
                onClick={handleSort}
                currentSort={sortConfig}
              />
              <th className="px-3 py-3 text-left border-b border-white/10 text-slate-400">
                Progress
              </th>
              <SortableHeader
                label="Vested"
                sortKey="vested"
                onClick={handleSort}
                currentSort={sortConfig}
              />
              <SortableHeader
                label="Releasable"
                sortKey="releasable"
                onClick={handleSort}
                currentSort={sortConfig}
              />
              <SortableHeader
                label="Unvested"
                sortKey="unvested"
                onClick={handleSort}
                currentSort={sortConfig}
              />
              <SortableHeader
                label="SUMR Bal"
                sortKey="summerBalance"
                onClick={handleSort}
                currentSort={sortConfig}
              />
              <SortableHeader
                label="xSUMR Bal"
                sortKey="xSummerBalance"
                onClick={handleSort}
                currentSort={sortConfig}
              />
              <th className="px-3 py-3 text-right border-b border-white/10 text-slate-400">
                Staking V2
              </th>
              <SortableHeader
                label="Staking V1"
                sortKey="governanceRewardsBalance"
                onClick={handleSort}
                currentSort={sortConfig}
              />
              <th className="px-3 py-3 text-center border-b border-white/10 text-slate-400">
                Escrow
              </th>
              <th className="px-3 py-3 text-right border-b border-white/10 text-slate-400">
                Retention
              </th>
              <th className="px-3 py-3 text-center border-b border-white/10 text-slate-400">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/5">
            {filteredAndSortedSnapshots.map((snap) => {
              const vestingProgressPct =
                snap.totalPlanned > BigInt(0)
                  ? Number((snap.vested * BigInt(100)) / snap.totalPlanned)
                  : 0

              return (
                <tr key={snap.codename} className="hover:bg-white/5 transition-colors group">
                  {/* Sticky Codename Column */}
                  <td className="px-3 py-3 font-semibold sticky left-0 bg-charcoal-900 group-hover:bg-charcoal-800 z-10 shadow-[4px_0_8px_-4px_rgba(0,0,0,0.3)] border-r border-white/5">
                    <div className="text-white">
                      {snap.codename}
                      <div className="font-normal text-[9px] text-slate-500 mt-0.5 opacity-70 uppercase tracking-wider">
                        {snap.version}
                      </div>
                    </div>
                  </td>

                  {/* Wallet / Owner */}
                  <td className="px-3 py-3">
                    <div className="flex flex-col">
                      <span className="text-primary font-mono text-[11px] font-medium">
                        {snap.owner.slice(0, 6)}...{snap.owner.slice(-4)}
                      </span>
                      {snap.vestingWallet ? (
                        <span className="text-slate-400 font-mono text-[10px]">
                          {snap.vestingWallet.slice(0, 6)}...{snap.vestingWallet.slice(-4)}
                        </span>
                      ) : (
                        <span className="text-slate-600 text-[10px]">—</span>
                      )}
                    </div>
                  </td>

                  <td className="px-3 py-3 text-right font-medium text-white">
                    {formatDecimalOutput(snap.totalPlanned, snap.decimals)}
                  </td>

                  <td className="px-3 py-3 min-w-[120px]">
                    <div className="space-y-1">
                      <ProgressBar value={vestingProgressPct} className="h-2" />
                      <span className="text-[10px] text-slate-500">
                        {vestingProgressPct.toFixed(1)}%
                      </span>
                    </div>
                  </td>

                  <td className="px-3 py-3 text-right text-emerald-400">
                    {formatDecimalOutput(snap.vested, snap.decimals)}
                  </td>

                  <td className="px-3 py-3 text-right text-yellow-400 font-medium">
                    {formatDecimalOutput(snap.releasable, snap.decimals)}
                  </td>

                  <td className="px-3 py-3 text-right text-slate-400">
                    {formatDecimalOutput(snap.unvested, snap.decimals)}
                  </td>

                  <td className="px-3 py-3 text-right text-slate-300">
                    {formatDecimalOutput(snap.summerBalance, snap.decimals)}
                  </td>

                  <td className="px-3 py-3 text-right text-slate-300">
                    {formatDecimalOutput(snap.xSummerBalance, snap.decimals)}
                  </td>

                  {/* Staking V2 Map */}
                  <td className="px-3 py-3 text-right min-w-[180px]">
                    <div className="flex flex-col items-end gap-0.5">
                      <span className="mb-1 text-slate-200">
                        {formatDecimalOutput(snap.stakingBalance, 18)}
                      </span>
                      {snap.stakes.length > 0 && (
                        <div className="flex flex-col gap-1 w-full mt-1">
                          {snap.stakes.map((stake, idx) => (
                            <div
                              key={idx}
                              className="flex items-center justify-end gap-2 bg-white/5 border border-white/10 rounded px-1.5 py-0.5 text-[10px]"
                            >
                              <span className="text-slate-400 font-mono">
                                {new Date(Number(stake.lockupEndTime) * 1000).toLocaleDateString()}
                              </span>
                              <div className="flex items-baseline gap-1">
                                <span className="text-slate-200 font-medium tabular-nums">
                                  {formatDecimalOutput(stake.amount, 18)}
                                </span>
                                <span className="text-slate-500 text-[9px] uppercase">SUMR</span>
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  </td>

                  <td className="px-3 py-3 text-right text-slate-300">
                    {formatDecimalOutput(snap.governanceRewardsBalance, 18)}
                  </td>

                  <td className="px-3 py-3 text-center">
                    {snap.inEscrow ? (
                      <span
                        className="inline-block w-2.5 h-2.5 rounded-full bg-emerald-500 ring-2 ring-emerald-500/30"
                        title="In Escrow"
                      />
                    ) : (
                      <span
                        className="inline-block w-2 h-2 rounded-full bg-white/10"
                        title="Not Escrow"
                      />
                    )}
                  </td>

                  {/* Retention Check */}
                  {(() => {
                    const currentTokens =
                      (snap.unvested || 0n) +
                      (snap.releasable || 0n) +
                      (snap.summerBalance || 0n) +
                      (snap.xSummerBalance || 0n)
                    const delta = currentTokens - (snap.totalPlanned || 0n)
                    const isOk = delta >= 0n
                    return (
                      <td
                        className={`px-3 py-3 text-right font-medium ${
                          snap.totalPlanned === 0n
                            ? 'text-slate-600'
                            : isOk
                              ? 'text-emerald-400'
                              : 'text-red-400'
                        }`}
                      >
                        {snap.totalPlanned === 0n ? (
                          '—'
                        ) : isOk ? (
                          <span title="All tokens accounted for">✓</span>
                        ) : (
                          <span
                            title={`Deficit: ${formatDecimalOutput(-delta, snap.decimals)} SUMR`}
                          >
                            −{formatDecimalOutput(-delta, snap.decimals)}
                          </span>
                        )}
                      </td>
                    )
                  })()}

                  <td className="px-3 py-3 text-center">
                    {chainId && (
                      <Link
                        href={`/vesting/${chainId}?address=${snap.owner}`}
                        className="text-primary hover:text-primary/80 font-bold text-xs"
                      >
                        View Details
                      </Link>
                    )}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </>
  )
}
