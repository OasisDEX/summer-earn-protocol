'use client'

import { useMemo, useState } from 'react'

import type { WalletSnapshot } from '@/lib/vesting-logic'
import { formatDecimalOutput } from '@/utils/decimals'

function StatCard({ label, value, suffix }: { label: string; value: string; suffix?: string }) {
  return (
    <div className="rounded-xl border border-gray-800 bg-gray-900/70 p-4 text-left space-y-1">
      <div className="text-[10px] uppercase tracking-wide text-gray-500">{label}</div>
      <div className="text-2xl font-bold text-white tracking-tight">
        {value} <span className="text-gray-500 text-sm font-normal">{suffix}</span>
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
      className="px-3 py-3 text-right border-b border-gray-700 cursor-pointer hover:bg-gray-700/50 transition-colors group select-none"
      onClick={() => onClick(sortKey)}
    >
      <div className="flex items-center justify-end gap-1">
        {label}
        <span className="text-gray-600 text-[10px]">
          {currentSort?.key === sortKey ? (currentSort.direction === 'asc' ? '▲' : '▼') : '↕'}
        </span>
      </div>
    </th>
  )
}

export default function VestingBatchTable({ initialSnapshots }: { initialSnapshots: any[] }) {
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

  // Sorting Logic
  const processedSnapshots = useMemo(() => {
    const data = [...snapshots]

    if (sortConfig) {
      data.sort((a, b) => {
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
  }, [snapshots, sortConfig])

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

  return (
    <>
      <div className="rounded-2xl border border-gray-800 bg-gray-900/70 p-4">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-center">
          <StatCard
            label="Total Planned"
            value={formatDecimalOutput(summaryTotals.totalPlanned, 18)}
            suffix="SUMR"
          />
          <StatCard
            label="Vested (Available + Claimed)"
            value={formatDecimalOutput(summaryTotals.vested, 18)}
            suffix="SUMR"
          />
          <StatCard
            label="Unvested Future"
            value={formatDecimalOutput(summaryTotals.unvested, 18)}
            suffix="SUMR"
          />
        </div>
      </div>

      {/* Table Container - Fixed Height for sticky headers to work well */}
      <div className="rounded-2xl border border-gray-800 bg-gray-900/70 overflow-x-auto max-h-[70vh] relative shadow-2xl">
        <table className="min-w-full text-xs md:text-sm text-gray-200 whitespace-nowrap">
          <thead className="bg-gray-800 sticky top-0 z-20 shadow-md">
            <tr>
              <th className="px-3 py-3 text-left sticky left-0 bg-gray-800 z-30 shadow-[4px_0_8px_-4px_rgba(0,0,0,0.5)] border-b border-gray-700">
                Codename
              </th>
              <th className="px-3 py-3 text-left border-b border-gray-700">Wallet / Owner</th>
              <SortableHeader
                label="Planned"
                sortKey="totalPlanned"
                onClick={handleSort}
                currentSort={sortConfig}
              />
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
              <th className="px-3 py-3 text-right border-b border-gray-700">Staking V2</th>
              <SortableHeader
                label="Staking V1"
                sortKey="governanceRewardsBalance"
                onClick={handleSort}
                currentSort={sortConfig}
              />
              <th className="px-3 py-3 text-center border-b border-gray-700">Escrow</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-800/60">
            {processedSnapshots.map((snap) => {
              return (
                <tr key={snap.codename} className="hover:bg-white/5 transition-colors group">
                  <td className="px-3 py-3 font-semibold sticky left-0 bg-gray-900 group-hover:bg-gray-800 z-10 shadow-[4px_0_8px_-4px_rgba(0,0,0,0.5)] border-r border-gray-800/50">
                    <div className="text-white">
                      {snap.codename}
                      <div className="font-normal text-[9px] text-gray-500 mt-0.5 opacity-70 uppercase tracking-wider">
                        {snap.version}
                      </div>
                    </div>
                  </td>
                  <td className="px-3 py-3">
                    <div className="flex flex-col">
                      <span className="text-blue-300 font-mono text-[10px]">
                        {snap.owner.slice(0, 6)}...{snap.owner.slice(-4)}
                      </span>
                      {snap.vestingWallet ? (
                        <span className="text-green-300 font-mono text-[10px]">
                          {snap.vestingWallet.slice(0, 6)}...{snap.vestingWallet.slice(-4)}
                        </span>
                      ) : (
                        <span className="text-gray-600 text-[10px]">—</span>
                      )}
                    </div>
                  </td>
                  <td className="px-3 py-3 text-right font-medium text-gray-100">
                    {formatDecimalOutput(snap.totalPlanned, snap.decimals)}
                  </td>
                  <td className="px-3 py-3 text-right text-gray-300">
                    {formatDecimalOutput(snap.vested, snap.decimals)}
                  </td>
                  <td className="px-3 py-3 text-right text-yellow-200 font-bold">
                    {formatDecimalOutput(snap.releasable, snap.decimals)}
                  </td>
                  <td className="px-3 py-3 text-right text-gray-500">
                    {formatDecimalOutput(snap.unvested, snap.decimals)}
                  </td>
                  <td className="px-3 py-3 text-right">
                    {formatDecimalOutput(snap.summerBalance, snap.decimals)}
                  </td>
                  <td className="px-3 py-3 text-right">
                    {formatDecimalOutput(snap.xSummerBalance, snap.decimals)}
                  </td>
                  <td className="px-3 py-3 text-right min-w-[180px]">
                    <div className="flex flex-col items-end gap-0.5">
                      <span className="mb-1">{formatDecimalOutput(snap.stakingBalance, 18)}</span>
                      {snap.stakes.length > 0 && (
                        <div className="flex flex-col gap-1 w-full">
                          {snap.stakes.map((stake, idx) => (
                            <div
                              key={idx}
                              className="flex items-center justify-end gap-2 bg-gray-800/50 border border-gray-700/30 rounded px-1.5 py-0.5 text-[10px]"
                            >
                              <span className="text-gray-500 font-mono">
                                {new Date(Number(stake.lockupEndTime) * 1000).toLocaleDateString()}
                              </span>
                              <div className="flex items-baseline gap-1">
                                <span className="text-gray-200 font-medium tabular-nums">
                                  {formatDecimalOutput(stake.amount, 18)}
                                </span>
                                <span className="text-gray-600 text-[9px] uppercase">SUMR</span>
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  </td>
                  <td className="px-3 py-3 text-right">
                    {formatDecimalOutput(snap.governanceRewardsBalance, 18)}
                  </td>
                  <td className="px-3 py-3 text-center">
                    {snap.inEscrow ? (
                      <span
                        className="inline-block w-2 h-2 rounded-full bg-green-500 ring-2 ring-green-900"
                        title="In Escrow"
                      />
                    ) : (
                      <span
                        className="inline-block w-2 h-2 rounded-full bg-gray-700"
                        title="Not Escrow"
                      />
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
