'use client'

import Link from 'next/link'
import { useMemo, useState } from 'react'

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
      totalPlanned: BigInt(s.totalPlanned),
      vested: BigInt(s.vested),
      releasable: BigInt(s.releasable),
      unvested: BigInt(s.unvested),
      summerBalance: BigInt(s.summerBalance),
      xSummerBalance: BigInt(s.xSummerBalance),
      stakingBalance: BigInt(s.stakingBalance),
      governanceRewardsBalance: BigInt(s.governanceRewardsBalance),
      stakes: s.stakes.map((k: any) => ({ ...k, amount: BigInt(k.amount) })),
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

    if (statusFilter !== 'all') {
      data = data.filter((s) => {
        const isCompleted = s.totalPlanned > BigInt(0) && s.vested >= s.totalPlanned
        return statusFilter === 'completed' ? isCompleted : !isCompleted
      })
    }

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase()
      data = data.filter(
        (s) =>
          s.codename?.toLowerCase().includes(q) ||
          s.owner?.toLowerCase().includes(q) ||
          s.vestingWallet?.toLowerCase().includes(q),
      )
    }

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
        return acc
      },
      { totalPlanned: 0n, vested: 0n, unvested: 0n },
    )
  }, [snapshots])

  const handleSort = (key: keyof WalletSnapshot) => {
    setSortConfig((current) => ({
      key,
      direction: current?.key === key && current.direction === 'asc' ? 'desc' : 'asc',
    }))
  }

  const uniqueRecipients = useMemo(() => new Set(snapshots.map((s) => s.owner)).size, [snapshots])

  return (
    <>
      <div className="glass rounded-2xl p-4 mb-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <StatCard
            label="Total Pool Value"
            value={formatDecimalOutput(summaryTotals.totalPlanned, 18)}
            suffix="SUMR"
            highlight
          />
          <StatCard label="Unique Recipients" value={String(uniqueRecipients)} suffix="wallets" />
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-4 mb-6">
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Search wallet or codename..."
          className="px-4 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/50 max-w-xs"
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
      <div className="glass rounded-2xl overflow-x-auto max-h-[70vh] relative">
        <table className="min-w-full text-xs md:text-sm text-slate-200 whitespace-nowrap">
          <thead className="bg-charcoal-800/80 sticky top-0 z-20">
            <tr>
              <th className="px-3 py-3 text-left sticky left-0 bg-charcoal-800/80 z-30 border-b border-white/10">
                Wallet Address
              </th>
              <SortableHeader
                label="Total Allocation"
                sortKey="totalPlanned"
                onClick={handleSort}
                currentSort={sortConfig}
              />
              <th className="px-3 py-3 text-left border-b border-white/10">Vesting Progress</th>
              <SortableHeader
                label="Amount Vested"
                sortKey="vested"
                onClick={handleSort}
                currentSort={sortConfig}
              />
              <th className="px-3 py-3 text-right border-b border-white/10">Amount Claimed</th>
              <th className="px-3 py-3 text-center border-b border-white/10">Status</th>
              <th className="px-3 py-3 text-center border-b border-white/10">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/5">
            {filteredAndSortedSnapshots.map((snap) => {
              const vestingProgressPct =
                snap.totalPlanned > BigInt(0)
                  ? Number((snap.vested * BigInt(100) * BigInt(10 ** 18)) / snap.totalPlanned) / 100
                  : 0
              const amountClaimed = snap.vested - snap.releasable
              const isCompleted = snap.totalPlanned > BigInt(0) && snap.vested >= snap.totalPlanned

              return (
                <tr key={snap.codename} className="hover:bg-white/5 transition-colors group">
                  <td className="px-3 py-3 sticky left-0 bg-charcoal-900 group-hover:bg-charcoal-800 z-10 border-r border-white/5">
                    <div className="flex flex-col">
                      <span className="text-primary font-mono text-sm font-medium">
                        {snap.owner.slice(0, 6)}...{snap.owner.slice(-4)}
                      </span>
                      {snap.vestingWallet && (
                        <span className="text-slate-500 font-mono text-[10px]">
                          {snap.vestingWallet.slice(0, 6)}...{snap.vestingWallet.slice(-4)}
                        </span>
                      )}
                      {snap.codename && (
                        <span className="text-[10px] text-slate-600 uppercase mt-0.5">
                          {snap.codename}
                        </span>
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
                  <td className="px-3 py-3 text-right text-slate-300">
                    {formatDecimalOutput(amountClaimed, snap.decimals)}
                  </td>
                  <td className="px-3 py-3 text-center">
                    <span
                      className={`inline-block px-2 py-0.5 rounded text-[10px] font-bold uppercase ${
                        isCompleted
                          ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                          : 'bg-primary/20 text-primary border border-primary/30'
                      }`}
                    >
                      {isCompleted ? 'Completed' : 'Active'}
                    </span>
                  </td>
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
