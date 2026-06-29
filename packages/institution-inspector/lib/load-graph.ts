import fs from 'node:fs'
import path from 'node:path'
import { GraphFileSchema, type GraphFile } from './graph-schema'

const DATA_DIR = path.join(process.cwd(), 'data')

export interface GraphRef {
  network: string
  env: string
  file: string
}

/** List the generated graph files in data/ (graph.<network>.<env>.json). */
export function listGraphs(): GraphRef[] {
  if (!fs.existsSync(DATA_DIR)) return []
  return fs
    .readdirSync(DATA_DIR)
    .map((f) => f.match(/^graph\.([^.]+)\.([^.]+)\.json$/))
    .filter((m): m is RegExpMatchArray => Boolean(m))
    .map((m) => ({ network: m[1], env: m[2], file: m[0] }))
    .sort((a, b) => a.network.localeCompare(b.network) || a.env.localeCompare(b.env))
}

export function loadGraph(network: string, env: string): GraphFile | null {
  const p = path.join(DATA_DIR, `graph.${network}.${env}.json`)
  if (!fs.existsSync(p)) return null
  return GraphFileSchema.parse(JSON.parse(fs.readFileSync(p, 'utf8')))
}

/** Load every generated graph, keyed by "network.env". */
export function loadAllGraphs(): Record<string, GraphFile> {
  const out: Record<string, GraphFile> = {}
  for (const ref of listGraphs()) {
    const g = loadGraph(ref.network, ref.env)
    if (g) out[`${ref.network}.${ref.env}`] = g
  }
  return out
}
