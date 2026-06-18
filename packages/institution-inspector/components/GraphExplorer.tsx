'use client'

import { useMemo, useState } from 'react'
import { Background, Controls, MiniMap, ReactFlow, type Node } from '@xyflow/react'
import { ChevronRight } from 'lucide-react'
import type { GraphFile, GraphNode } from '@/lib/graph-schema'
import { drillTarget, levelOf, selectSubgraph, toReactFlow, type ViewState } from '@/lib/subgraph'
import { ChainIdContext } from './graph-context'
import { InspectorNode } from './InspectorNode'
import { NodeDetailDrawer } from './NodeDetailDrawer'

const nodeTypes = { inspector: InspectorNode }

export function GraphExplorer({ graphs }: { graphs: Record<string, GraphFile> }) {
  const keys = Object.keys(graphs).sort()
  const [graphKey, setGraphKey] = useState(keys.includes('base.production') ? 'base.production' : keys[0])
  const [view, setView] = useState<ViewState>({})
  const [selectedId, setSelectedId] = useState<string | null>(null)

  const graph = graphs[graphKey]
  const level = levelOf(view)

  const { rfNodes, rfEdges, byId } = useMemo(() => {
    const sub = selectSubgraph(graph, view)
    const { rfNodes, rfEdges } = toReactFlow(sub.nodes, sub.edges)
    const byId = new Map(sub.nodes.map((n) => [n.id, n]))
    return { rfNodes, rfEdges, byId }
  }, [graph, view])

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
                {i > 0 && <ChevronRight size={14} className="text-slate-300" />}
                <button
                  onClick={c.onClick}
                  className={i === crumbs.length - 1 ? 'font-semibold text-on-surface' : 'text-primary hover:underline'}
                >
                  {c.label}
                </button>
              </span>
            ))}
          </nav>

          <span className="ml-auto text-xs text-on-surface-variant">
            {level} · {rfNodes.length} nodes · {graph.onchain.fetched ? 'on-chain verified' : 'config-only'}
          </span>
        </div>

        <ReactFlow
          key={`${graphKey}:${view.inst ?? ''}:${view.fleet ?? ''}`}
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
          <MiniMap
            pannable
            zoomable
            className="!bg-surface-container"
            maskColor="rgba(13,14,16,0.7)"
            nodeColor="#47484a"
          />
        </ReactFlow>

        <NodeDetailDrawer node={selectedNode} onClose={() => setSelectedId(null)} />
      </div>
    </ChainIdContext.Provider>
  )
}
