'use client'

import { useMemo, useState } from 'react'
import { Background, Controls, MiniMap, ReactFlow, type Node } from '@xyflow/react'
import { ChevronRight, RefreshCw } from 'lucide-react'
import type { GraphEdge, GraphFile, GraphNode } from '@/lib/graph-schema'
import { drillTarget, levelOf, selectSubgraph, toReactFlow, type ViewState } from '@/lib/subgraph'
import { ChainIdContext } from './graph-context'
import { InspectorNode } from './InspectorNode'
import { NodeDetailDrawer } from './NodeDetailDrawer'

const nodeTypes = { inspector: InspectorNode }

// An edge that asserts an on-chain fact (role grant / registry membership) rather than structure.
const isClaimEdge = (e: GraphEdge) =>
  e.type === 'hasRole' || e.type === 'governs' || (e.type === 'system' && e.target.startsWith('registry:'))

export function GraphExplorer({ graphs }: { graphs: Record<string, GraphFile> }) {
  const keys = Object.keys(graphs).sort()
  const [graphKey, setGraphKey] = useState(keys.includes('base.production') ? 'base.production' : keys[0])
  const [view, setView] = useState<ViewState>({})
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [verifiedOnly, setVerifiedOnly] = useState(false)
  const [override, setOverride] = useState<Record<string, GraphFile>>({})
  const [refreshing, setRefreshing] = useState(false)

  const graph = override[graphKey] ?? graphs[graphKey]
  const level = levelOf(view)

  const { rfNodes, rfEdges, byId } = useMemo(() => {
    const sub = selectSubgraph(graph, view)
    let nodes = sub.nodes
    let edges = sub.edges
    if (verifiedOnly) {
      edges = edges.filter((e) => !isClaimEdge(e) || e.data?.verifiedOnChain === true)
      const connected = new Set<string>()
      edges.forEach((e) => {
        connected.add(e.source)
        connected.add(e.target)
      })
      // Drop role/timelock nodes left with no verified connection.
      nodes = nodes.filter((n) => (n.type !== 'roleHolder' && n.type !== 'timelock') || connected.has(n.id))
    }
    const { rfNodes, rfEdges } = toReactFlow(nodes, edges)
    return { rfNodes, rfEdges, byId: new Map(nodes.map((n) => [n.id, n])) }
  }, [graph, view, verifiedOnly])

  const nodesWithSelection: Node[] = rfNodes.map((n) => ({ ...n, selected: n.id === selectedId }))
  const selectedNode: GraphNode | null = selectedId ? byId.get(selectedId) ?? null : null

  const onNodeClick = (_: unknown, node: Node) => {
    const g = byId.get(node.id)
    if (!g) return
    const target = drillTarget(g.type, g.id)
    if (target) {
      setView(target)
      setSelectedId(null)
    } else {
      setSelectedId(node.id)
    }
  }

  const refresh = async () => {
    setRefreshing(true)
    try {
      const [network, env] = graphKey.split('.')
      const r = await fetch(`/api/refresh?network=${network}&env=${env}`)
      if (r.ok) {
        const data = (await r.json()) as GraphFile
        setOverride((p) => ({ ...p, [graphKey]: data }))
      }
    } finally {
      setRefreshing(false)
    }
  }

  const crumbs: Array<{ label: string; onClick: () => void }> = [
    { label: 'Institutions', onClick: () => setView({}) },
  ]
  if (view.inst) crumbs.push({ label: view.inst, onClick: () => setView({ inst: view.inst }) })
  if (view.fleet) crumbs.push({ label: view.fleet, onClick: () => {} })

  return (
    <ChainIdContext.Provider value={graph.chainId}>
      <div className="relative h-full w-full">
        {/* Top bar */}
        <div className="absolute left-0 right-0 top-0 z-10 flex items-center gap-4 border-b border-outline-variant bg-surface/90 px-4 py-2 backdrop-blur">
          <select
            value={graphKey}
            onChange={(e) => {
              setGraphKey(e.target.value)
              setView({})
              setSelectedId(null)
            }}
            className="rounded border border-outline-variant bg-surface-container px-2 py-1 text-sm text-on-surface"
          >
            {keys.map((k) => (
              <option key={k} value={k}>
                {k.replace('.', ' · ')}
              </option>
            ))}
          </select>

          <nav className="flex items-center gap-1 text-sm">
            {crumbs.map((c, i) => (
              <span key={i} className="flex items-center gap-1">
                {i > 0 && <ChevronRight size={14} className="text-outline" />}
                <button
                  onClick={c.onClick}
                  className={i === crumbs.length - 1 ? 'font-semibold text-on-surface' : 'text-primary hover:underline'}
                >
                  {c.label}
                </button>
              </span>
            ))}
          </nav>

          <label className="ml-auto flex items-center gap-1.5 text-xs text-on-surface-variant">
            <input type="checkbox" checked={verifiedOnly} onChange={(e) => setVerifiedOnly(e.target.checked)} />
            verified only
          </label>

          <button
            onClick={refresh}
            disabled={refreshing}
            className="flex items-center gap-1.5 rounded border border-outline-variant bg-surface-container px-2 py-1 text-xs text-on-surface hover:border-primary disabled:opacity-50"
            title="Re-run config + on-chain verification for this network/env"
          >
            <RefreshCw size={12} className={refreshing ? 'animate-spin' : ''} />
            {refreshing ? 'Refreshing…' : 'Refresh on-chain'}
          </button>

          <span className="text-xs text-on-surface-variant">
            {level} · {rfNodes.length} nodes · {graph.onchain.fetched ? `verified @ ${graph.onchain.blockNumber}` : 'config-only'}
          </span>
        </div>

        <ReactFlow
          key={`${graphKey}:${view.inst ?? ''}:${view.fleet ?? ''}:${verifiedOnly}`}
          nodes={nodesWithSelection}
          edges={rfEdges}
          nodeTypes={nodeTypes}
          onNodeClick={onNodeClick}
          onPaneClick={() => setSelectedId(null)}
          nodesDraggable={false}
          nodesConnectable={false}
          fitView
          fitViewOptions={{ padding: 0.2 }}
          proOptions={{ hideAttribution: true }}
          colorMode="dark"
          className="bg-surface"
        >
          <Background color="#242629" gap={20} />
          <Controls showInteractive={false} />
          <MiniMap pannable zoomable className="!bg-surface-container" maskColor="rgba(13,14,16,0.7)" nodeColor="#47484a" />
        </ReactFlow>

        {/* Legend */}
        <div className="absolute bottom-3 left-3 z-10 flex flex-col gap-1 rounded-lg border border-outline-variant bg-surface-container/90 px-3 py-2 text-[10px] text-on-surface-variant backdrop-blur">
          <LegendRow color="#68fadd" label="verified on-chain" />
          <LegendRow color="#ff716c" label="drift (config ≠ chain)" dashed />
          <LegendRow color="#757578" label="unverified / config-only" dashed />
        </div>

        <NodeDetailDrawer node={selectedNode} onClose={() => setSelectedId(null)} />
      </div>
    </ChainIdContext.Provider>
  )
}

function LegendRow({ color, label, dashed }: { color: string; label: string; dashed?: boolean }) {
  return (
    <span className="flex items-center gap-2">
      <span
        className="inline-block h-0 w-5"
        style={{ borderTop: `2px ${dashed ? 'dashed' : 'solid'} ${color}` }}
      />
      {label}
    </span>
  )
}
