'use client'

import { useState } from 'react'

import { Skeleton } from '../../../components/Skeleton'
import { AddressDisplay, Table, TBody, Td, Th, THead, Tr } from '../../../components/ui'
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
      <AddressDisplay
        value={address}
        href={`${explorer}/address/${address}`}
        className="text-sm text-on-surface-variant"
      />
      {label && (
        <span className="text-[11px] uppercase tracking-wider text-primary bg-primary/10 px-1.5 py-0.5 rounded">
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
      <Tr hover className="border-t border-white/5">
        <Td>
          <button
            onClick={() => setExpanded((v) => !v)}
            className="flex items-center gap-2 text-left"
            aria-expanded={expanded}
          >
            <span className="text-primary text-xs">{expanded ? '▼' : '▶'}</span>
            <div>
              <div className="text-sm font-medium text-on-surface">{fleet.name}</div>
              <AddressLink chainId={chainId} address={fleet.address} />
            </div>
          </button>
        </Td>
        <Td numeric className="text-sm text-on-surface">
          {formatDecimalOutput(fleet.pendingAssets, fleet.assetDecimals)}{' '}
          <span className="text-on-surface-variant">{fleet.assetSymbol}</span>
        </Td>
        <Td align="right">
          <button
            onClick={() => shake(chainId, instance.address, fleet.address, onShaken)}
            disabled={busy || nothingToShake}
            className="bg-primary hover:bg-primary/90 disabled:opacity-40 disabled:cursor-not-allowed text-on-primary px-3 py-1.5 rounded-lg text-xs font-semibold transition-all"
            title={nothingToShake ? 'Nothing to shake' : 'Shake this fleet commander'}
          >
            {busy ? 'Shaking…' : 'Shake'}
          </button>
        </Td>
      </Tr>
      {expanded && (
        <Tr className="bg-black/20">
          <Td colSpan={3} className="pt-0 pb-4">
            <div className="mt-1 rounded-lg border border-white/5 overflow-hidden">
              <Table>
                <THead className="bg-white/5">
                  <Tr>
                    <Th>Recipient</Th>
                    <Th numeric>Allocation</Th>
                    <Th numeric>Projected payout</Th>
                  </Tr>
                </THead>
                <TBody>
                  {instance.streams.length === 0 && (
                    <Tr>
                      <Td colSpan={3} className="text-on-surface-variant/80">
                        No recipients configured.
                      </Td>
                    </Tr>
                  )}
                  {instance.streams.map((s) => (
                    <Tr key={s.recipient}>
                      <Td>
                        <AddressLink chainId={chainId} address={s.recipient} />
                      </Td>
                      <Td numeric className="text-on-surface-variant">
                        {formatPercentage(s.allocation)}
                      </Td>
                      <Td numeric className="text-on-surface">
                        {formatDecimalOutput(
                          projectedPayout(fleet.pendingAssets, s.allocation),
                          fleet.assetDecimals,
                        )}{' '}
                        {fleet.assetSymbol}
                      </Td>
                    </Tr>
                  ))}
                  <Tr className="border-t border-white/10 text-on-surface-variant">
                    <Td className="italic">Treasury (remainder)</Td>
                    <Td />
                    <Td numeric>
                      {formatDecimalOutput(remainder > 0n ? remainder : 0n, fleet.assetDecimals)}{' '}
                      {fleet.assetSymbol}
                    </Td>
                  </Tr>
                </TBody>
              </Table>
            </div>
          </Td>
        </Tr>
      )}
    </>
  )
}

function StreamsTable({ chainId, streams }: { chainId: ChainId; streams: TipStreamEntry[] }) {
  if (streams.length === 0) {
    return (
      <p className="text-sm text-on-surface-variant/80 px-4 py-3">No tip streams configured.</p>
    )
  }
  return (
    <Table>
      <THead className="border-b border-white/10">
        <Tr>
          <Th>Recipient</Th>
          <Th numeric>Allocation</Th>
          <Th numeric>Locked until</Th>
        </Tr>
      </THead>
      <TBody>
        {streams.map((s) => (
          <Tr key={s.recipient}>
            <Td>
              <AddressLink chainId={chainId} address={s.recipient} />
            </Td>
            <Td numeric className="text-on-surface">
              {formatPercentage(s.allocation)}
            </Td>
            <Td numeric className="text-on-surface-variant">
              {lockedUntilLabel(s.lockedUntilEpoch)}
            </Td>
          </Tr>
        ))}
      </TBody>
    </Table>
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
          <h3 className="text-lg font-semibold text-on-surface">{instance.label}</h3>
          <AddressLink chainId={chainId} address={instance.address} />
          {instance.paused && (
            <span className="text-[11px] uppercase tracking-wider text-warning bg-warning/10 px-2 py-0.5 rounded">
              Paused
            </span>
          )}
        </div>
        <div className="flex items-center gap-4">
          <div className="text-right">
            <p className="text-[11px] uppercase tracking-wider text-on-surface-variant/80">
              Total allocation
            </p>
            <p className="text-sm font-semibold text-on-surface tabular-nums">
              {formatPercentage(instance.totalAllocation)}
            </p>
          </div>
          <button
            onClick={() => shakeAll(chainId, instance.address, onShaken)}
            disabled={busyAll}
            className="bg-primary/20 hover:bg-primary/30 border border-primary/30 disabled:opacity-40 disabled:cursor-not-allowed text-on-surface px-4 py-2 rounded-lg text-sm font-semibold transition-all"
            title="Shake all active fleet commanders on this chain"
          >
            {busyAll ? 'Shaking all…' : 'Shake all'}
          </button>
        </div>
      </div>

      <div className="px-2 pt-3">
        <p className="text-xs font-semibold uppercase tracking-wider text-on-surface-variant/80 px-2 mb-1">
          Tip streams
        </p>
        <StreamsTable chainId={chainId} streams={instance.streams} />
      </div>

      <div className="px-2 py-3">
        <p className="text-xs font-semibold uppercase tracking-wider text-on-surface-variant/80 px-2 mb-1">
          Fleet commanders — pending (≈)
        </p>
        {instance.fleets.length === 0 ? (
          <p className="text-sm text-on-surface-variant/80 px-4 py-3">
            No active fleet commanders.
          </p>
        ) : (
          <Table>
            <THead className="border-b border-white/10">
              <Tr>
                <Th>Fleet commander</Th>
                <Th numeric>Pending</Th>
                <Th align="right">Action</Th>
              </Tr>
            </THead>
            <TBody>
              {instance.fleets.map((fleet) => (
                <FleetRow
                  key={fleet.address}
                  chainId={chainId}
                  instance={instance}
                  fleet={fleet}
                  onShaken={onShaken}
                />
              ))}
            </TBody>
          </Table>
        )}
      </div>
    </div>
  )
}

export function TipJarChainSection({ chainId }: { chainId: ChainId }) {
  const { instances, loading, error, refresh } = useTipJarData(chainId)

  return (
    <section className="space-y-4">
      <h2 className="text-xl font-bold text-on-surface flex items-center gap-3">
        {CHAIN_NAMES[chainId]}
        <span className="text-xs font-normal text-on-surface-variant/80">Chain {chainId}</span>
      </h2>

      {loading && (
        <div className="space-y-3">
          <Skeleton className="h-24 w-full" />
          <Skeleton className="h-24 w-full" />
        </div>
      )}

      {error && (
        <div className="glass rounded-xl border border-error/20 px-4 py-3 text-sm text-error">
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
