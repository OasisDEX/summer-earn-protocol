'use client'

import { useMemo, useState } from 'react'

import { StatCard } from '../../components/StatCard'
import { PageHeader } from '../../components/ui'
import { formatAddress } from '../../utils/address'
import { AdminCard } from './components/AdminCard'
import { ChainAndOAppPicker } from './components/ChainAndOAppPicker'
import { EditConfigDrawer } from './components/EditConfigDrawer'
import { PendingChangesCart } from './components/PendingChangesCart'
import { RouteDetailPanel } from './components/RouteDetailPanel'
import { RouteMatrix } from './components/RouteMatrix'
import { SafeExportModal } from './components/SafeExportModal'
import { SubmitEditsModal } from './components/SubmitEditsModal'
import { useDvnMetadata } from './hooks/useDvnMetadata'
import { useEditAuthorizations } from './hooks/useEditAuthorizations'
import { useOAppAdmin } from './hooks/useOAppAdmin'
import {
  getDesiredRouteConfig,
  getEid,
  getEndpoint,
  getOAppAddress,
  listRemoteChainsWithDvns,
} from './lib/configReader'
import type { ChainName, OAppKind, PendingEdit } from './lib/types'

export function LzConfigDashboard() {
  const [sourceChain, setSourceChain] = useState<ChainName>('base')
  const [oApp, setOApp] = useState<OAppKind>('SummerToken')
  const [selectedRemote, setSelectedRemote] = useState<ChainName | null>(null)

  // Each pending edit carries a stable `_id` so the cart's React keys survive
  // mid-list removals. The id is private to the cart UI; downstream consumers
  // (Safe export, direct submit) still treat the entries as plain PendingEdits.
  const [pending, setPending] = useState<(PendingEdit & { _id: string })[]>([])
  const [editingRemote, setEditingRemote] = useState<ChainName | null>(null)
  const [exportOpen, setExportOpen] = useState(false)
  const [submitOpen, setSubmitOpen] = useState(false)

  const authorizations = useEditAuthorizations(pending)

  const remotes = useMemo(() => listRemoteChainsWithDvns(sourceChain), [sourceChain])
  const endpoint = getEndpoint(sourceChain)
  const eid = getEid(sourceChain)
  const oAppAddress = getOAppAddress(sourceChain, oApp)

  // Warm shared queries so children can read from the React Query cache.
  useDvnMetadata()
  useOAppAdmin(sourceChain, oApp)

  return (
    <div className="max-w-7xl mx-auto px-6 py-8">
      <PageHeader
        title="LayerZero Config Explorer"
        description={
          <>
            Compare on-chain LZ ULN configuration vs the desired configuration in{' '}
            <code className="bg-white/5 px-1 py-0.5 rounded text-xs">config/index.json</code>, stage
            edits and export them as Safe Transaction Builder JSON files.
          </>
        }
      />

      <section className="mb-6">
        <ChainAndOAppPicker
          sourceChain={sourceChain}
          onChainChange={(c) => {
            setSourceChain(c)
            setSelectedRemote(null)
          }}
          oApp={oApp}
          onOAppChange={(o) => {
            setOApp(o)
            setSelectedRemote(null)
          }}
        />
      </section>

      <section className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Endpoint" value={formatAddress(endpoint)} />
        <StatCard label="EID" value={String(eid || '—')} />
        <StatCard label="OApp" value={formatAddress(oAppAddress)} />
        <StatCard label="Routes configured" value={String(remotes.length)} highlight />
      </section>

      <section className="mb-8">
        <AdminCard sourceChain={sourceChain} oApp={oApp} />
      </section>

      <section className="mb-8">
        <RouteMatrix
          sourceChain={sourceChain}
          oApp={oApp}
          remotes={remotes}
          selectedRemote={selectedRemote}
          onSelect={setSelectedRemote}
        />
      </section>

      {selectedRemote && (
        <section className="mb-8">
          <RouteDetailPanel
            sourceChain={sourceChain}
            oApp={oApp}
            remoteChain={selectedRemote}
            onEdit={oAppAddress ? () => setEditingRemote(selectedRemote) : undefined}
          />
        </section>
      )}

      {editingRemote && oAppAddress && (
        <EditConfigDrawer
          sourceChain={sourceChain}
          oApp={oApp}
          oAppAddress={oAppAddress}
          remoteChain={editingRemote}
          desired={getDesiredRouteConfig(sourceChain, editingRemote, oApp)}
          onClose={() => setEditingRemote(null)}
          onSubmit={(edits) => {
            const withIds = edits.map((e) => ({ ...e, _id: crypto.randomUUID() }))
            setPending((prev) => [...prev, ...withIds])
            setEditingRemote(null)
          }}
        />
      )}

      {pending.length > 0 && (
        <PendingChangesCart
          pending={pending}
          authorizations={authorizations}
          onRemove={(i) => setPending((prev) => prev.filter((_, idx) => idx !== i))}
          onClear={() => setPending([])}
          onExport={() => setExportOpen(true)}
          onSubmit={() => setSubmitOpen(true)}
        />
      )}

      {exportOpen && <SafeExportModal pending={pending} onClose={() => setExportOpen(false)} />}

      {submitOpen && (
        <SubmitEditsModal
          pending={pending}
          authorizations={authorizations}
          onClose={() => setSubmitOpen(false)}
        />
      )}
    </div>
  )
}
