'use client'

import { useMemo, useState } from 'react'

import { StatCard } from '../../components/StatCard'
import { ChainAndOAppPicker } from './components/ChainAndOAppPicker'
import { RouteDetailPanel } from './components/RouteDetailPanel'
import { RouteMatrix } from './components/RouteMatrix'
import {
  getEid,
  getEndpoint,
  getOAppAddress,
  listRemoteChainsWithDvns,
} from './lib/configReader'
import type { ChainName, OAppKind } from './lib/types'

function shortenAddress(addr: string | null): string {
  if (!addr) return '—'
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

export function LzConfigDashboard() {
  const [sourceChain, setSourceChain] = useState<ChainName>('base')
  const [oApp, setOApp] = useState<OAppKind>('SummerToken')
  const [selectedRemote, setSelectedRemote] = useState<ChainName | null>(null)

  const remotes = useMemo(() => listRemoteChainsWithDvns(sourceChain), [sourceChain])
  const endpoint = getEndpoint(sourceChain)
  const eid = getEid(sourceChain)
  const oAppAddress = getOAppAddress(sourceChain, oApp)

  return (
    <div className="max-w-7xl mx-auto px-6 py-8">
      <header className="mb-8">
        <h1 className="text-3xl font-bold text-white mb-2">LayerZero Config Explorer</h1>
        <p className="text-slate-400 max-w-3xl">
          Read-only view of LZ ULN configuration. Compare on-chain state vs the desired
          configuration in{' '}
          <code className="bg-white/5 px-1 py-0.5 rounded text-xs">config/index.json</code>.
          Editing &amp; Safe transaction export are coming next.
        </p>
      </header>

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
        <StatCard label="Endpoint" value={shortenAddress(endpoint)} />
        <StatCard label="EID" value={String(eid || '—')} />
        <StatCard label="OApp" value={shortenAddress(oAppAddress)} />
        <StatCard label="Routes configured" value={String(remotes.length)} highlight />
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
          />
        </section>
      )}

      <section className="mt-4">
        <div className="glass p-4 rounded-xl text-sm text-slate-400">
          Editing not yet enabled — edit drawer + Safe export coming next.
        </div>
      </section>
    </div>
  )
}
