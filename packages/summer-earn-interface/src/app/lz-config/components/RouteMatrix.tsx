'use client'

import type { Address, Hex } from 'viem'

import { GlassCard } from '../../../components/GlassCard'
import type { DvnMetadata } from '../hooks/useDvnMetadata'
import { useDvnMetadata } from '../hooks/useDvnMetadata'
import { useOAppAdmin } from '../hooks/useOAppAdmin'
import { useOnChainRouteState } from '../hooks/useOnChainRouteState'
import { getDesiredRouteConfig } from '../lib/configReader'
import { addressToBytes32 } from '../lib/encodeDecode'
import { evaluateRoute } from '../lib/recommendations'
import type {
  ChainName,
  DesiredRouteConfig,
  DvnSeverity,
  EnforcedOptionsState,
  ExecutorConfig,
  OAppAdminState,
  OAppKind,
  UlnConfig,
} from '../lib/types'

type Status = 'ok' | 'drift' | 'unset' | 'na' | 'loading' | 'error'

const STATUS_LABEL: Record<Status, string> = {
  ok: 'OK',
  drift: 'DRIFT',
  unset: 'NOT SET',
  na: 'n/a',
  loading: '…',
  error: 'RPC ERR',
}

const STATUS_CLASS: Record<Status, string> = {
  ok: 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30',
  drift: 'bg-amber-500/15 text-amber-300 border-amber-500/30',
  unset: 'bg-red-500/15 text-red-300 border-red-500/30',
  na: 'bg-white/5 text-slate-500 border-white/10',
  loading: 'bg-white/5 text-slate-500 border-white/10 animate-pulse',
  error: 'bg-red-500/15 text-red-300 border-red-500/30',
}

function StatusPill({ status, title }: { status: Status; title?: string }) {
  return (
    <span
      title={title}
      className={`inline-block px-2 py-0.5 text-xs font-semibold rounded border ${STATUS_CLASS[status]}`}
    >
      {STATUS_LABEL[status]}
    </span>
  )
}

type EnforcedStatus = 'ok' | 'empty' | 'notread' | 'loading' | 'error'

const ENFORCED_LABEL: Record<EnforcedStatus, string> = {
  ok: 'OK',
  empty: 'EMPTY',
  notread: 'NOT READ',
  loading: '…',
  error: 'RPC ERR',
}

const ENFORCED_CLASS: Record<EnforcedStatus, string> = {
  ok: 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30',
  empty: 'bg-red-500/15 text-red-300 border-red-500/30',
  notread: 'bg-white/5 text-slate-500 border-white/10',
  loading: 'bg-white/5 text-slate-500 border-white/10 animate-pulse',
  error: 'bg-red-500/15 text-red-300 border-red-500/30',
}

function EnforcedPill({ status, title }: { status: EnforcedStatus; title?: string }) {
  return (
    <span
      title={title}
      className={`inline-block px-2 py-0.5 text-xs font-semibold rounded border ${ENFORCED_CLASS[status]}`}
    >
      {ENFORCED_LABEL[status]}
    </span>
  )
}

function enforcedStatusFor(value: Hex | null | undefined): EnforcedStatus {
  if (value === null || value === undefined) return 'notread'
  if (value === '0x') return 'empty'
  return 'ok'
}

function RecsBadge({
  count,
  worst,
  isLoading,
}: {
  count: number
  worst: DvnSeverity | null
  isLoading: boolean
}) {
  if (isLoading) {
    return (
      <span className="inline-block px-2 py-0.5 text-xs font-semibold rounded border bg-white/5 text-slate-500 border-white/10 animate-pulse">
        …
      </span>
    )
  }
  if (count === 0 || worst === null) {
    return (
      <span className="inline-block px-2 py-0.5 text-xs font-semibold rounded border bg-emerald-500/15 text-emerald-300 border-emerald-500/30">
        ✓
      </span>
    )
  }
  if (worst === 'error') {
    return (
      <span className="inline-block px-2 py-0.5 text-xs font-semibold rounded border bg-red-500/15 text-red-300 border-red-500/30">
        {count} ✕
      </span>
    )
  }
  if (worst === 'warn') {
    return (
      <span className="inline-block px-2 py-0.5 text-xs font-semibold rounded border bg-amber-500/15 text-amber-300 border-amber-500/30">
        {count} ⚠
      </span>
    )
  }
  return (
    <span className="inline-block px-2 py-0.5 text-xs font-semibold rounded border bg-white/5 text-slate-300 border-white/10">
      {count} ℹ
    </span>
  )
}

function sameAddrCI(a: string | null | undefined, b: string | null | undefined): boolean {
  if (!a || !b) return false
  return a.toLowerCase() === b.toLowerCase()
}

function ulnEqual(a: UlnConfig | null, b: UlnConfig | null): boolean {
  if (!a || !b) return false
  if (a.confirmations !== b.confirmations) return false
  if (a.requiredDVNCount !== b.requiredDVNCount) return false
  if (a.optionalDVNCount !== b.optionalDVNCount) return false
  if (a.optionalDVNThreshold !== b.optionalDVNThreshold) return false
  const sortLower = (arr: readonly string[]) => [...arr].map((x) => x.toLowerCase()).sort()
  const aReq = sortLower(a.requiredDVNs)
  const bReq = sortLower(b.requiredDVNs)
  if (aReq.length !== bReq.length || aReq.some((v, i) => v !== bReq[i])) return false
  const aOpt = sortLower(a.optionalDVNs)
  const bOpt = sortLower(b.optionalDVNs)
  if (aOpt.length !== bOpt.length || aOpt.some((v, i) => v !== bOpt[i])) return false
  return true
}

function peerStatus(desired: DesiredRouteConfig | null, onChainPeer: Hex | null): Status {
  if (!desired || !desired.peerAddress) return 'na'
  if (!onChainPeer || /^0x0+$/.test(onChainPeer)) return 'unset'
  const desiredB32 = addressToBytes32(desired.peerAddress).toLowerCase()
  return onChainPeer.toLowerCase() === desiredB32 ? 'ok' : 'drift'
}

function ulnStatusFn(desired: UlnConfig | null, onChain: UlnConfig | null): Status {
  if (!desired) return 'na'
  if (!onChain) return 'unset'
  return ulnEqual(desired, onChain) ? 'ok' : 'drift'
}

function addressStatusFn(desired: Address | null, onChain: Address | null): Status {
  if (!desired) return 'na'
  if (!onChain) return 'unset'
  return sameAddrCI(desired, onChain) ? 'ok' : 'drift'
}

function executorStatusFn(desired: ExecutorConfig | null, onChain: ExecutorConfig | null): Status {
  if (!desired) return 'na'
  if (!onChain) return 'unset'
  if (desired.maxMessageSize !== onChain.maxMessageSize) return 'drift'
  return sameAddrCI(desired.executorAddress, onChain.executorAddress) ? 'ok' : 'drift'
}

interface RouteMatrixProps {
  sourceChain: ChainName
  oApp: OAppKind
  remotes: ChainName[]
  selectedRemote: ChainName | null
  onSelect: (remote: ChainName) => void
}

export function RouteMatrix({
  sourceChain,
  oApp,
  remotes,
  selectedRemote,
  onSelect,
}: RouteMatrixProps) {
  // Fire shared queries once at the matrix level so all rows share the result.
  const { data: dvnMetadata } = useDvnMetadata()
  const { data: admin } = useOAppAdmin(sourceChain, oApp)

  return (
    <GlassCard>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-slate-500 text-xs uppercase tracking-wider">
              <th className="text-left py-2 px-3">Remote</th>
              <th className="text-left py-2 px-3">Peer</th>
              <th className="text-left py-2 px-3">Send ULN</th>
              <th className="text-left py-2 px-3">Receive ULN</th>
              <th className="text-left py-2 px-3">Send Lib</th>
              <th className="text-left py-2 px-3">Receive Lib</th>
              <th className="text-left py-2 px-3">Executor</th>
              <th className="text-left py-2 px-3">Enf SEND</th>
              <th className="text-left py-2 px-3">Enf S+C</th>
              <th className="text-left py-2 px-3">Recs</th>
              <th className="py-2 px-3" />
            </tr>
          </thead>
          <tbody>
            {remotes.length === 0 && (
              <tr>
                <td colSpan={11} className="py-6 text-center text-slate-500">
                  No remote routes configured for this source chain.
                </td>
              </tr>
            )}
            {remotes.map((remote) => (
              <RouteMatrixRow
                key={remote}
                sourceChain={sourceChain}
                oApp={oApp}
                remoteChain={remote}
                isSelected={remote === selectedRemote}
                onClick={() => onSelect(remote)}
                dvnMetadata={dvnMetadata}
                admin={admin ?? null}
              />
            ))}
          </tbody>
        </table>
      </div>
    </GlassCard>
  )
}

function RouteMatrixRow({
  sourceChain,
  oApp,
  remoteChain,
  isSelected,
  onClick,
  dvnMetadata,
  admin,
}: {
  sourceChain: ChainName
  oApp: OAppKind
  remoteChain: ChainName
  isSelected: boolean
  onClick: () => void
  dvnMetadata: DvnMetadata | undefined
  admin: OAppAdminState | null
}) {
  const desired = getDesiredRouteConfig(sourceChain, remoteChain, oApp)
  const { data: onChain, isLoading, error } = useOnChainRouteState(sourceChain, oApp, remoteChain)
  const errorMessage = error instanceof Error ? error.message : error ? String(error) : undefined

  const peer: Status = error
    ? 'error'
    : isLoading
      ? 'loading'
      : peerStatus(desired, (onChain?.peerBytes32 ?? null) as Hex | null)
  const sendUln: Status = error
    ? 'error'
    : isLoading
      ? 'loading'
      : ulnStatusFn(desired?.uln ?? null, onChain?.sendUln ?? null)
  const recvUln: Status = error
    ? 'error'
    : isLoading
      ? 'loading'
      : ulnStatusFn(desired?.uln ?? null, onChain?.receiveUln ?? null)
  const sendLib: Status = error
    ? 'error'
    : isLoading
      ? 'loading'
      : addressStatusFn(desired?.sendLib ?? null, onChain?.sendLib ?? null)
  const recvLib: Status = error
    ? 'error'
    : isLoading
      ? 'loading'
      : addressStatusFn(desired?.receiveLib ?? null, onChain?.receiveLib ?? null)
  const exec: Status = error
    ? 'error'
    : isLoading
      ? 'loading'
      : executorStatusFn(desired?.executor ?? null, onChain?.executor ?? null)

  const enforced: EnforcedOptionsState | null = onChain?.enforced ?? null
  const enfSend: EnforcedStatus = error
    ? 'error'
    : isLoading
      ? 'loading'
      : enforced
        ? enforcedStatusFor(enforced.send)
        : 'notread'
  const enfSC: EnforcedStatus = error
    ? 'error'
    : isLoading
      ? 'loading'
      : enforced
        ? enforcedStatusFor(enforced.sendAndCall)
        : 'notread'

  const recs =
    error || isLoading
      ? []
      : evaluateRoute({
          sourceChain,
          desired,
          onChain: onChain ?? null,
          admin,
          dvnMetadata,
        })
  const worst: DvnSeverity | null = recs.length > 0 ? recs[0].severity : null

  return (
    <tr
      onClick={onClick}
      className={`cursor-pointer transition-colors border-t border-white/5 ${
        isSelected ? 'bg-primary/5' : 'hover:bg-white/5'
      }`}
    >
      <td className="py-3 px-3 capitalize text-white font-medium" title={errorMessage}>
        {remoteChain}
      </td>
      <td className="py-3 px-3">
        <StatusPill status={peer} title={errorMessage} />
      </td>
      <td className="py-3 px-3">
        <StatusPill status={sendUln} title={errorMessage} />
      </td>
      <td className="py-3 px-3">
        <StatusPill status={recvUln} title={errorMessage} />
      </td>
      <td className="py-3 px-3">
        <StatusPill status={sendLib} title={errorMessage} />
      </td>
      <td className="py-3 px-3">
        <StatusPill status={recvLib} title={errorMessage} />
      </td>
      <td className="py-3 px-3">
        <StatusPill status={exec} title={errorMessage} />
      </td>
      <td className="py-3 px-3">
        <EnforcedPill status={enfSend} title={errorMessage} />
      </td>
      <td className="py-3 px-3">
        <EnforcedPill status={enfSC} title={errorMessage} />
      </td>
      <td className="py-3 px-3">
        <RecsBadge count={recs.length} worst={worst} isLoading={isLoading} />
      </td>
      <td className="py-3 px-3 text-slate-500">{isSelected ? '▾' : '▸'}</td>
    </tr>
  )
}
