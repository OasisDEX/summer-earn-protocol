'use client'

import { useState } from 'react'

import { Skeleton } from '../../../components/Skeleton'
import { CHAIN_BLOCK_EXPLORERS, CHAIN_NAMES } from '../../../config/chains'
import type { ChainId } from '../../../types'
import { getAddressLabel } from '../../../utils/configAddresses'
import { formatDecimalOutput, formatPercentage } from '../../../utils/decimals'
import { useTipJarActions } from '../hooks/useTipJarActions'
import {
  type TipJarFleetEntry,
  type TipJarInstanceData,
  type TipStreamEntry,
  useTipJarData,
} from '../hooks/useTipJarData'
import { projectedPayout } from '../lib/format'

function shorten(addr: string): string {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

function lockedUntilLabel(epoch: bigint): string {
  if (epoch === 0n) return 'Unlocked'
  const ms = Number(epoch) * 1000
  if (ms <= Date.now()) return 'Unlocked'
  return new Date(ms).toLocaleString()
}

function AddressLink({ chainId, address }: { chainId: ChainId; address: string }) {
  const explorer = CHAIN_BLOCK_EXPLORERS[chainId]
  const label = getAddressLabel(chainId, address)
  return (
    <span className="inline-flex items-center gap-2">
      <a
        href={`${explorer}/address/${address}`}
        target="_blank"
        rel="noopener noreferrer"
        className="font-mono text-sm text-slate-300 hover:text-white transition-colors"
        title={address}
      >
        {shorten(address)}
      </a>
      {label && (
        <span className="text-[10px] uppercase tracking-wider text-primary bg-primary/10 px-1.5 py-0.5 rounded">
          {label}
        </span>
      )}
    </span>
  )
}

function FleetRow({
  chainId,
  instance,
  fleet,
  onShaken,
}: {
  chainId: ChainId
  instance: TipJarInstanceData
  fleet: TipJarFleetEntry
  onShaken: () => void
}) {
  const [expanded, setExpanded] = useState(false)
  const { shake, isPending } = useTipJarActions()
  const shakeKey = `${instance.address}:${fleet.address}`
  const busy = isPending(shakeKey)
  const nothingToShake = fleet.pendingAssets === 0n

  const distributed = instance.streams.reduce(
    (acc, s) => acc + projectedPayout(fleet.pendingAssets, s.allocation),
    0n,
  )
  const remainder = fleet.pendingAssets - distributed

  return (
    <>
      <tr className="border-t border-white/5 hover:bg-white/5">
        <td className="py-3 px-4">
          <button
            onClick={() => setExpanded((v) => !v)}
            className="flex items-center gap-2 text-left"
            aria-expanded={expanded}
          >
            <span className="text-primary text-xs">{expanded ? '▼' : '▶'}</span>
            <div>
              <div className="text-sm font-medium text-white">{fleet.name}</div>
              <AddressLink chainId={chainId} address={fleet.address} />
            </div>
          </button>
        </td>
        <td className="py-3 px-4 text-right text-sm text-white">
          {formatDecimalOutput(fleet.pendingAssets, fleet.assetDecimals)}{' '}
          <span className="text-slate-400">{fleet.assetSymbol}</span>
        </td>
        <td className="py-3 px-4 text-right">
          <button
            onClick={() => shake(chainId, instance.address, fleet.address, onShaken)}
            disabled={busy || nothingToShake}
            className="bg-primary hover:bg-primary/90 disabled:opacity-40 disabled:cursor-not-allowed text-white px-3 py-1.5 rounded-lg text-xs font-semibold transition-all"
            title={nothingToShake ? 'Nothing to shake' : 'Shake this fleet commander'}
          >
            {busy ? 'Shaking…' : 'Shake'}
          </button>
        </td>
      </tr>
      {expanded && (
        <tr className="bg-black/20">
          <td colSpan={3} className="px-4 pb-4">
            <div className="mt-1 rounded-lg border border-white/5 overflow-hidden">
              <table className="w-full text-xs">
                <thead className="bg-white/5 text-slate-400">
                  <tr>
                    <th className="text-left py-2 px-3 font-medium">Recipient</th>
                    <th className="text-right py-2 px-3 font-medium">Allocation</th>
                    <th className="text-right py-2 px-3 font-medium">Projected payout</th>
                  </tr>
                </thead>
                <tbody>
                  {instance.streams.length === 0 && (
                    <tr>
                      <td colSpan={3} className="py-2 px-3 text-slate-500">
                        No recipients configured.
                      </td>
                    </tr>
                  )}
                  {instance.streams.map((s) => (
                    <tr key={s.recipient} className="border-t border-white/5">
                      <td className="py-2 px-3">
                        <AddressLink chainId={chainId} address={s.recipient} />
                      </td>
                      <td className="py-2 px-3 text-right text-slate-300">
                        {formatPercentage(s.allocation)}
                      </td>
                      <td className="py-2 px-3 text-right text-white">
                        {formatDecimalOutput(
                          projectedPayout(fleet.pendingAssets, s.allocation),
                          fleet.assetDecimals,
                        )}{' '}
                        {fleet.assetSymbol}
                      </td>
                    </tr>
                  ))}
                  <tr className="border-t border-white/10 text-slate-400">
                    <td className="py-2 px-3 italic">Treasury (remainder)</td>
                    <td className="py-2 px-3" />
                    <td className="py-2 px-3 text-right">
                      {formatDecimalOutput(remainder > 0n ? remainder : 0n, fleet.assetDecimals)}{' '}
                      {fleet.assetSymbol}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </td>
        </tr>
      )}
    </>
  )
}

function StreamsTable({ chainId, streams }: { chainId: ChainId; streams: TipStreamEntry[] }) {
  if (streams.length === 0) {
    return <p className="text-sm text-slate-500 px-4 py-3">No tip streams configured.</p>
  }
  return (
    <table className="w-full text-sm">
      <thead className="text-slate-400 border-b border-white/10">
        <tr>
          <th className="text-left py-2 px-4 font-medium">Recipient</th>
          <th className="text-right py-2 px-4 font-medium">Allocation</th>
          <th className="text-right py-2 px-4 font-medium">Locked until</th>
        </tr>
      </thead>
      <tbody>
        {streams.map((s) => (
          <tr key={s.recipient} className="border-t border-white/5">
            <td className="py-2 px-4">
              <AddressLink chainId={chainId} address={s.recipient} />
            </td>
            <td className="py-2 px-4 text-right text-white">{formatPercentage(s.allocation)}</td>
            <td className="py-2 px-4 text-right text-slate-400">
              {lockedUntilLabel(s.lockedUntilEpoch)}
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}

function InstanceCard({
  chainId,
  instance,
  onShaken,
}: {
  chainId: ChainId
  instance: TipJarInstanceData
  onShaken: () => void
}) {
  const { shakeAll, isPending } = useTipJarActions()
  const allKey = `${instance.address}:all`
  const busyAll = isPending(allKey)

  return (
    <div className="glass rounded-xl border border-white/10 overflow-hidden">
      <div className="flex flex-wrap items-center justify-between gap-4 px-4 py-4 border-b border-white/10">
        <div className="flex items-center gap-3">
          <h3 className="text-lg font-semibold text-white">{instance.label}</h3>
          <AddressLink chainId={chainId} address={instance.address} />
          {instance.paused && (
            <span className="text-[10px] uppercase tracking-wider text-amber-400 bg-amber-400/10 px-2 py-0.5 rounded">
              Paused
            </span>
          )}
        </div>
        <div className="flex items-center gap-4">
          <div className="text-right">
            <p className="text-[10px] uppercase tracking-wider text-slate-500">Total allocation</p>
            <p className="text-sm font-semibold text-white">
              {formatPercentage(instance.totalAllocation)}
            </p>
          </div>
          <button
            onClick={() => shakeAll(chainId, instance.address, onShaken)}
            disabled={busyAll}
            className="bg-primary/20 hover:bg-primary/30 border border-primary/30 disabled:opacity-40 disabled:cursor-not-allowed text-white px-4 py-2 rounded-lg text-sm font-semibold transition-all"
            title="Shake all active fleet commanders on this chain"
          >
            {busyAll ? 'Shaking all…' : 'Shake all'}
          </button>
        </div>
      </div>

      <div className="px-2 pt-3">
        <p className="text-xs font-semibold uppercase tracking-wider text-slate-500 px-2 mb-1">
          Tip streams
        </p>
        <StreamsTable chainId={chainId} streams={instance.streams} />
      </div>

      <div className="px-2 py-3">
        <p className="text-xs font-semibold uppercase tracking-wider text-slate-500 px-2 mb-1">
          Fleet commanders — pending (≈)
        </p>
        {instance.fleets.length === 0 ? (
          <p className="text-sm text-slate-500 px-4 py-3">No active fleet commanders.</p>
        ) : (
          <table className="w-full text-sm">
            <thead className="text-slate-400 border-b border-white/10">
              <tr>
                <th className="text-left py-2 px-4 font-medium">Fleet commander</th>
                <th className="text-right py-2 px-4 font-medium">Pending</th>
                <th className="text-right py-2 px-4 font-medium">Action</th>
              </tr>
            </thead>
            <tbody>
              {instance.fleets.map((fleet) => (
                <FleetRow
                  key={fleet.address}
                  chainId={chainId}
                  instance={instance}
                  fleet={fleet}
                  onShaken={onShaken}
                />
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}

export function TipJarChainSection({ chainId }: { chainId: ChainId }) {
  const { instances, loading, error, refresh } = useTipJarData(chainId)

  return (
    <section className="space-y-4">
      <h2 className="text-xl font-bold text-white flex items-center gap-3">
        {CHAIN_NAMES[chainId]}
        <span className="text-xs font-normal text-slate-500">Chain {chainId}</span>
      </h2>

      {loading && (
        <div className="space-y-3">
          <Skeleton className="h-24 w-full" />
          <Skeleton className="h-24 w-full" />
        </div>
      )}

      {error && (
        <div className="glass rounded-xl border border-red-500/20 px-4 py-3 text-sm text-red-400">
          Failed to load: {error.message}
        </div>
      )}

      {!loading &&
        !error &&
        instances.map((instance) => (
          <InstanceCard
            key={instance.address}
            chainId={chainId}
            instance={instance}
            onShaken={() => {
              void refresh()
            }}
          />
        ))}
    </section>
  )
}
