'use client'

import type { Address, Hex } from 'viem'

import { GlassCard } from '../../../components/GlassCard'
import { Table, TableContainer, TBody, Td, Th, THead, Tr } from '../../../components/ui'
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
  ok: 'bg-success/15 text-success border-success/30',
  drift: 'bg-warning/15 text-warning border-warning/30',
  unset: 'bg-error/15 text-error border-error/30',
  na: 'bg-white/5 text-on-surface-variant border-white/10',
  loading: 'bg-white/5 text-on-surface-variant border-white/10 animate-pulse',
  error: 'bg-error/15 text-error border-error/30',
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
  ok: 'bg-success/15 text-success border-success/30',
  empty: 'bg-error/15 text-error border-error/30',
  notread: 'bg-white/5 text-on-surface-variant border-white/10',
  loading: 'bg-white/5 text-on-surface-variant border-white/10 animate-pulse',
  error: 'bg-error/15 text-error border-error/30',
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
      <span className="inline-block px-2 py-0.5 text-xs font-semibold rounded border bg-white/5 text-on-surface-variant border-white/10 animate-pulse">
        …
      </span>
    )
  }
  if (count === 0 || worst === null) {
    return (
      <span className="inline-block px-2 py-0.5 text-xs font-semibold rounded border bg-success/15 text-success border-success/30">
        ✓
      </span>
    )
  }
  if (worst === 'error') {
    return (
      <span className="inline-block px-2 py-0.5 text-xs font-semibold rounded border bg-error/15 text-error border-error/30">
        {count} ✕
      </span>
    )
  }
  if (worst === 'warn') {
    return (
      <span className="inline-block px-2 py-0.5 text-xs font-semibold rounded border bg-warning/15 text-warning border-warning/30">
        {count} ⚠
      </span>
    )
  }
  return (
    <span className="inline-block px-2 py-0.5 text-xs font-semibold rounded border bg-info/15 text-info border-info/30">
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
      <TableContainer>
        <Table>
          <THead>
            <Tr>
              <Th>Remote</Th>
              <Th>Peer</Th>
              <Th>Send ULN</Th>
              <Th>Receive ULN</Th>
              <Th>Send Lib</Th>
              <Th>Receive Lib</Th>
              <Th>Executor</Th>
              <Th>Enf SEND</Th>
              <Th>Enf S+C</Th>
              <Th>Recs</Th>
              <Th />
            </Tr>
          </THead>
          <TBody>
            {remotes.length === 0 && (
              <Tr>
                <Td colSpan={11} align="center" className="py-6 text-on-surface-variant">
                  No remote routes configured for this source chain.
                </Td>
              </Tr>
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
          </TBody>
        </Table>
      </TableContainer>
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
      : ulnStatusFn(desired?.sendUln ?? null, onChain?.sendUln ?? null)
  const recvUln: Status = error
    ? 'error'
    : isLoading
      ? 'loading'
      : ulnStatusFn(desired?.receiveUln ?? null, onChain?.receiveUln ?? null)
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
  // When the underlying RPC read failed, surface that as an error rec instead of
  // letting the empty `recs` array render as a green "✓".
  const worst: DvnSeverity | null = error ? 'error' : recs.length > 0 ? recs[0].severity : null
  const recsCount = error ? 1 : recs.length

  return (
    <Tr
      onClick={onClick}
      className={`cursor-pointer transition-colors ${isSelected ? 'bg-primary/5' : 'hover:bg-white/5'}`}
    >
      <Td className="capitalize text-on-surface font-medium" title={errorMessage}>
        {remoteChain}
      </Td>
      <Td>
        <StatusPill status={peer} title={errorMessage} />
      </Td>
      <Td>
        <StatusPill status={sendUln} title={errorMessage} />
      </Td>
      <Td>
        <StatusPill status={recvUln} title={errorMessage} />
      </Td>
      <Td>
        <StatusPill status={sendLib} title={errorMessage} />
      </Td>
      <Td>
        <StatusPill status={recvLib} title={errorMessage} />
      </Td>
      <Td>
        <StatusPill status={exec} title={errorMessage} />
      </Td>
      <Td>
        <EnforcedPill status={enfSend} title={errorMessage} />
      </Td>
      <Td>
        <EnforcedPill status={enfSC} title={errorMessage} />
      </Td>
      <Td>
        <RecsBadge count={recsCount} worst={worst} isLoading={isLoading} />
      </Td>
      <Td className="text-on-surface-variant">{isSelected ? '▾' : '▸'}</Td>
    </Tr>
  )
}
