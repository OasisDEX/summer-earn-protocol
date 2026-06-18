import dagre from '@dagrejs/dagre'
import type { Edge, Node } from '@xyflow/react'
import type { GraphFile, GraphNode, NodeType } from './graph-schema'

export type Level = 'L1' | 'L2' | 'L3'

export interface ViewState {
  inst?: string
  fleet?: string
}

export function levelOf(view: ViewState): Level {
  if (view.fleet) return 'L3'
  if (view.inst) return 'L2'
  return 'L1'
}

/**
 * Filter the full graph down to the nodes/edges relevant for the current drill-down level.
 * Node ids encode their owners (`sys:<inst>:…`, `fleet:<inst>:<name>`, `ark:<inst>:<name>:<i>`),
 * so filtering is prefix-based. Role-holder / timelock nodes are pulled in when they have an
 * edge into the anchor set.
 */
export function selectSubgraph(graph: GraphFile, view: ViewState): { nodes: GraphNode[]; edges: GraphFile['edges'] } {
  const level = levelOf(view)
  const byId = new Map(graph.nodes.map((n) => [n.id, n]))
  const anchor = new Set<string>()

  if (level === 'L1') {
    for (const n of graph.nodes) if (n.type === 'institution' || n.id.startsWith('registry:')) anchor.add(n.id)
  } else if (level === 'L2') {
    const inst = view.inst!
    for (const n of graph.nodes) {
      if (
        n.id === `inst:${inst}` ||
        n.id.startsWith(`sys:${inst}:`) ||
        n.id.startsWith(`tl:${inst}:`) ||
        n.id.startsWith(`fleet:${inst}:`)
      )
        anchor.add(n.id)
    }
  } else {
    const prefix = `${view.inst}:${view.fleet}`
    for (const n of graph.nodes) {
      if (
        n.id === `fleet:${prefix}` ||
        n.id === `fc:${prefix}` ||
        n.id === `buf:${prefix}` ||
        n.id.startsWith(`ark:${prefix}:`) ||
        n.id === `rvin:${prefix}` ||
        n.id === `rvout:${prefix}`
      )
        anchor.add(n.id)
    }
  }

  // Pull in roleHolder/timelock nodes that connect into the anchor set.
  const included = new Set(anchor)
  for (const e of graph.edges) {
    if (anchor.has(e.target) && byId.has(e.source)) {
      const src = byId.get(e.source)!
      if (src.type === 'roleHolder' || src.type === 'timelock') included.add(e.source)
    }
  }

  const nodes = graph.nodes.filter((n) => included.has(n.id))
  const edges = graph.edges.filter((e) => included.has(e.source) && included.has(e.target))
  return { nodes, edges }
}

const NODE_W = 210
const NODE_H = 76

/** Auto-layout with dagre (left-to-right), returning React Flow nodes + edges. */
export function toReactFlow(
  nodes: GraphNode[],
  edges: GraphFile['edges'],
  direction: 'LR' | 'TB' = 'LR',
): { rfNodes: Node[]; rfEdges: Edge[] } {
  const g = new dagre.graphlib.Graph()
  g.setDefaultEdgeLabel(() => ({}))
  g.setGraph({ rankdir: direction, nodesep: 36, ranksep: 90, marginx: 24, marginy: 24 })
  nodes.forEach((n) => g.setNode(n.id, { width: NODE_W, height: NODE_H }))
  edges.forEach((e) => g.setEdge(e.source, e.target))
  dagre.layout(g)

  const rfNodes: Node[] = nodes.map((n) => {
    const p = g.node(n.id)
    return {
      id: n.id,
      type: 'inspector',
      position: { x: (p?.x ?? 0) - NODE_W / 2, y: (p?.y ?? 0) - NODE_H / 2 },
      data: { ...n.data, nodeType: n.type },
    }
  })

  const rfEdges: Edge[] = edges.map((e) => {
    const isRole = e.type === 'hasRole' || e.type === 'governs'
    return {
      id: e.id,
      source: e.source,
      target: e.target,
      label: e.data?.role,
      animated: isRole && e.data?.verifiedOnChain === false,
      style: isRole ? { stroke: '#94a3b8', strokeDasharray: e.data?.verifiedOnChain ? undefined : '4 4' } : { stroke: '#cbd5e1' },
      labelStyle: { fontSize: 10, fill: '#64748b' },
    }
  })

  return { rfNodes, rfEdges }
}

/** Node types that are "drillable" (clicking navigates deeper). */
export function drillTarget(nodeType: NodeType, id: string): ViewState | null {
  if (nodeType === 'institution') {
    const inst = id.slice('inst:'.length)
    return { inst }
  }
  if (nodeType === 'fleet') {
    const [, inst, fleet] = id.split(':')
    return { inst, fleet }
  }
  return null
}
