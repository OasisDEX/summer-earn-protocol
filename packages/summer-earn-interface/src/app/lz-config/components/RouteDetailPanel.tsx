'use client'

import type { ReactNode } from 'react'
import type { Address, Hex } from 'viem'

import { GlassCard } from '../../../components/GlassCard'
import type { DvnMetadata } from '../hooks/useDvnMetadata'
import { lookupDvn, useDvnMetadata } from '../hooks/useDvnMetadata'
import { useOAppAdmin } from '../hooks/useOAppAdmin'
import { useOnChainRouteState } from '../hooks/useOnChainRouteState'
import { getDesiredRouteConfig } from '../lib/configReader'
import { addressToBytes32, bytes32ToAddress } from '../lib/encodeDecode'
import { evaluateRoute } from '../lib/recommendations'
import type { ChainName, OAppKind, Recommendation, UlnConfig } from '../lib/types'

interface Props {
  sourceChain: ChainName
  oApp: OAppKind
  remoteChain: ChainName
  onEdit?: () => void
}

function sameAddrCI(a: string | null | undefined, b: string | null | undefined): boolean {
  if (!a || !b) return false
  return a.toLowerCase() === b.toLowerCase()
}

function ulnFieldDiffer(a: UlnConfig | null, b: UlnConfig | null, field: keyof UlnConfig): boolean {
  if (!a || !b) return Boolean(a) !== Boolean(b)
  const av = a[field]
  const bv = b[field]
  if (Array.isArray(av) && Array.isArray(bv)) {
    const aN = [...av].map((x) => String(x).toLowerCase()).sort()
    const bN = [...bv].map((x) => String(x).toLowerCase()).sort()
    return aN.length !== bN.length || aN.some((v, i) => v !== bN[i])
  }
  return av !== bv
}

function Row({
  label,
  desired,
  actual,
  differ,
}: {
  label: string
  desired: ReactNode
  actual: ReactNode
  differ?: boolean
}) {
  return (
    <div className="grid grid-cols-2 gap-4 py-2 border-b border-white/5 last:border-b-0">
      <div>
        <div className="text-xs uppercase tracking-wider text-slate-500 mb-1">
          {label} (desired)
        </div>
        <div
          className={`font-mono text-xs break-all ${differ ? 'text-amber-300' : 'text-slate-300'}`}
        >
          {desired ?? '—'}
        </div>
      </div>
      <div>
        <div className="text-xs uppercase tracking-wider text-slate-500 mb-1">
          {label} (on-chain)
        </div>
        <div
          className={`font-mono text-xs break-all ${differ ? 'text-amber-300' : 'text-slate-300'}`}
        >
          {actual ?? '—'}
        </div>
      </div>
    </div>
  )
}

function fmtAddr(a: Address | null | undefined): string {
  return a ?? '—'
}

function DvnAddrLine({
  address,
  metadata,
  chain,
}: {
  address: string
  metadata: DvnMetadata | undefined
  chain: ChainName
}) {
  const info = lookupDvn(metadata, chain, address)
  return (
    <span className="inline-flex flex-wrap items-center gap-1.5">
      <span>{address}</span>
      {info && (
        <span className="inline-block px-1.5 py-0.5 rounded text-[10px] font-semibold border bg-white/5 text-slate-300 border-white/10">
          {info.canonicalName}
        </span>
      )}
      {info?.deprecated && (
        <span className="inline-block px-1.5 py-0.5 rounded text-[10px] font-semibold border bg-red-500/15 text-red-300 border-red-500/30">
          deprecated
        </span>
      )}
    </span>
  )
}

function fmtDvnList(
  arr: readonly string[] | undefined,
  metadata: DvnMetadata | undefined,
  chain: ChainName,
): ReactNode {
  if (!arr || arr.length === 0) return '—'
  return (
    <ul className="space-y-1">
      {arr.map((x) => (
        <li key={x}>
          <DvnAddrLine address={x} metadata={metadata} chain={chain} />
        </li>
      ))}
    </ul>
  )
}

function UlnSection({
  title,
  desired,
  actual,
  metadata,
  sourceChain,
}: {
  title: string
  desired: UlnConfig | null
  actual: UlnConfig | null
  metadata: DvnMetadata | undefined
  sourceChain: ChainName
}) {
  return (
    <div className="pt-4">
      <h4 className="text-sm font-semibold text-white mb-2">{title}</h4>
      <Row
        label="confirmations"
        desired={desired ? String(desired.confirmations) : '—'}
        actual={actual ? String(actual.confirmations) : '—'}
        differ={ulnFieldDiffer(desired, actual, 'confirmations')}
      />
      <Row
        label="requiredDVNCount"
        desired={desired ? String(desired.requiredDVNCount) : '—'}
        actual={actual ? String(actual.requiredDVNCount) : '—'}
        differ={ulnFieldDiffer(desired, actual, 'requiredDVNCount')}
      />
      <Row
        label="optionalDVNCount"
        desired={desired ? String(desired.optionalDVNCount) : '—'}
        actual={actual ? String(actual.optionalDVNCount) : '—'}
        differ={ulnFieldDiffer(desired, actual, 'optionalDVNCount')}
      />
      <Row
        label="optionalDVNThreshold"
        desired={desired ? String(desired.optionalDVNThreshold) : '—'}
        actual={actual ? String(actual.optionalDVNThreshold) : '—'}
        differ={ulnFieldDiffer(desired, actual, 'optionalDVNThreshold')}
      />
      <Row
        label="requiredDVNs"
        desired={fmtDvnList(desired?.requiredDVNs, metadata, sourceChain)}
        actual={fmtDvnList(actual?.requiredDVNs, metadata, sourceChain)}
        differ={ulnFieldDiffer(desired, actual, 'requiredDVNs')}
      />
      <Row
        label="optionalDVNs"
        desired={fmtDvnList(desired?.optionalDVNs, metadata, sourceChain)}
        actual={fmtDvnList(actual?.optionalDVNs, metadata, sourceChain)}
        differ={ulnFieldDiffer(desired, actual, 'optionalDVNs')}
      />
    </div>
  )
}

function EnforcedValue({ value }: { value: Hex | null | undefined }) {
  if (value === null || value === undefined) {
    return <span className="font-mono text-xs text-slate-500">—</span>
  }
  if (value === '0x') {
    return <span className="text-xs font-semibold text-red-300">No options set</span>
  }
  return <span className="font-mono text-xs text-slate-300 break-all">{value}</span>
}

function EnforcedSection({
  send,
  sendAndCall,
}: {
  send: Hex | null | undefined
  sendAndCall: Hex | null | undefined
}) {
  return (
    <div className="pt-4">
      <h4 className="text-sm font-semibold text-white mb-2">Enforced Options</h4>
      <div className="space-y-2">
        <div className="grid grid-cols-[200px,1fr] items-start gap-3 py-1 border-b border-white/5">
          <span className="text-xs uppercase tracking-wider text-slate-500">
            Message Type 1 (SEND)
          </span>
          <EnforcedValue value={send} />
        </div>
        <div className="grid grid-cols-[200px,1fr] items-start gap-3 py-1">
          <span className="text-xs uppercase tracking-wider text-slate-500">
            Message Type 2 (SEND_AND_CALL)
          </span>
          <EnforcedValue value={sendAndCall} />
        </div>
      </div>
    </div>
  )
}

const SEVERITY_STYLES: Record<
  Recommendation['severity'],
  { icon: string; rowClass: string; iconClass: string }
> = {
  error: {
    icon: '✕',
    rowClass: 'border-red-500/30 bg-red-500/5',
    iconClass: 'text-red-300',
  },
  warn: {
    icon: '⚠',
    rowClass: 'border-amber-500/30 bg-amber-500/5',
    iconClass: 'text-amber-300',
  },
  info: {
    icon: 'ℹ',
    rowClass: 'border-white/10 bg-white/5',
    iconClass: 'text-slate-400',
  },
}

function RecommendationsSection({ recs }: { recs: Recommendation[] }) {
  return (
    <div className="pt-4">
      <h4 className="text-sm font-semibold text-white mb-2">Recommendations</h4>
      {recs.length === 0 ? (
        <div className="text-xs text-emerald-300 px-3 py-2 rounded border border-emerald-500/30 bg-emerald-500/5">
          ✓ No issues detected on this route.
        </div>
      ) : (
        <ul className="space-y-2">
          {recs.map((r) => {
            const s = SEVERITY_STYLES[r.severity]
            return (
              <li
                key={r.id}
                className={`flex items-start gap-2 px-3 py-2 rounded border ${s.rowClass}`}
              >
                <span className={`font-bold leading-tight ${s.iconClass}`}>{s.icon}</span>
                <span className="text-xs text-slate-300">{r.message}</span>
              </li>
            )
          })}
        </ul>
      )}
    </div>
  )
}

export function RouteDetailPanel({ sourceChain, oApp, remoteChain, onEdit }: Props) {
  const desired = getDesiredRouteConfig(sourceChain, remoteChain, oApp)
  const { data: onChain, isLoading, error } = useOnChainRouteState(sourceChain, oApp, remoteChain)
  const { data: admin } = useOAppAdmin(sourceChain, oApp)
  const { data: dvnMetadata } = useDvnMetadata()

  if (isLoading) {
    return (
      <GlassCard>
        <div className="text-slate-400 py-8 text-center">Loading on-chain config…</div>
      </GlassCard>
    )
  }
  if (error) {
    return (
      <GlassCard>
        <div className="text-red-400 py-8 text-center">Error: {error.message}</div>
      </GlassCard>
    )
  }

  const desiredPeerB32 = desired?.peerAddress ? addressToBytes32(desired.peerAddress) : null
  const actualPeerB32 = onChain?.peerBytes32 ?? null
  const actualPeerAddr = actualPeerB32 ? bytes32ToAddress(actualPeerB32) : null

  const peerDiffer = (desiredPeerB32 ?? '').toLowerCase() !== (actualPeerB32 ?? '').toLowerCase()
  const sendLibDiffer = !sameAddrCI(desired?.sendLib, onChain?.sendLib)
  const recvLibDiffer = !sameAddrCI(desired?.receiveLib, onChain?.receiveLib)
  const executorAddrDiffer = !sameAddrCI(
    desired?.executor.executorAddress,
    onChain?.executor?.executorAddress,
  )
  const executorSizeDiffer =
    (desired?.executor.maxMessageSize ?? null) !== (onChain?.executor?.maxMessageSize ?? null)

  const recs = evaluateRoute({
    sourceChain,
    desired,
    onChain: onChain ?? null,
    admin: admin ?? null,
    dvnMetadata,
  })

  return (
    <GlassCard>
      <header className="mb-4 flex items-center justify-between gap-4">
        <h3 className="text-lg font-semibold text-white">
          {oApp}: {sourceChain} → <span className="capitalize">{remoteChain}</span>
        </h3>
        <button
          type="button"
          onClick={onEdit}
          disabled={!onEdit}
          className={`px-4 py-2 text-sm rounded-lg transition-colors ${
            onEdit
              ? 'bg-primary/20 text-primary hover:bg-primary/30'
              : 'bg-white/5 text-slate-500 cursor-not-allowed'
          }`}
        >
          Edit route
        </button>
      </header>

      <Row
        label="Peer (bytes32)"
        desired={desiredPeerB32 ?? '—'}
        actual={actualPeerB32 ?? '—'}
        differ={peerDiffer}
      />
      <Row
        label="Peer (address)"
        desired={fmtAddr(desired?.peerAddress ?? null)}
        actual={fmtAddr(actualPeerAddr)}
        differ={peerDiffer}
      />
      <Row
        label="Send library"
        desired={fmtAddr(desired?.sendLib ?? null)}
        actual={fmtAddr(onChain?.sendLib ?? null)}
        differ={sendLibDiffer}
      />
      <Row
        label="Receive library"
        desired={fmtAddr(desired?.receiveLib ?? null)}
        actual={fmtAddr(onChain?.receiveLib ?? null)}
        differ={recvLibDiffer}
      />
      <Row
        label="Executor address"
        desired={fmtAddr(desired?.executor.executorAddress ?? null)}
        actual={fmtAddr(onChain?.executor?.executorAddress ?? null)}
        differ={executorAddrDiffer}
      />
      <Row
        label="Executor maxMessageSize"
        desired={desired ? String(desired.executor.maxMessageSize) : '—'}
        actual={onChain?.executor ? String(onChain.executor.maxMessageSize) : '—'}
        differ={executorSizeDiffer}
      />

      <UlnSection
        title="Send ULN config"
        desired={desired?.sendUln ?? null}
        actual={onChain?.sendUln ?? null}
        metadata={dvnMetadata}
        sourceChain={sourceChain}
      />
      <UlnSection
        title="Receive ULN config"
        desired={desired?.receiveUln ?? null}
        actual={onChain?.receiveUln ?? null}
        metadata={dvnMetadata}
        sourceChain={sourceChain}
      />

      <EnforcedSection
        send={onChain?.enforced?.send}
        sendAndCall={onChain?.enforced?.sendAndCall}
      />

      <RecommendationsSection recs={recs} />
    </GlassCard>
  )
}
