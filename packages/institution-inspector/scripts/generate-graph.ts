import fs from 'node:fs'
import path from 'node:path'
import { GraphFileSchema, type GraphFile } from '../lib/graph-schema'
import { buildConfigGraph, type Env } from './build-config-graph'

/**
 * Generate the normalized inspection graph for a network/env.
 *
 *   pnpm generate -- --network base --env production [--onchain]
 *
 * Pass A (config + Ignition) always runs. Pass B (on-chain verification) is added later
 * and gated behind --onchain; for now the file is written with onchain.fetched=false.
 */

function arg(name: string, fallback?: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`)
  if (i !== -1 && process.argv[i + 1] && !process.argv[i + 1].startsWith('--')) return process.argv[i + 1]
  return fallback
}
const hasFlag = (name: string) => process.argv.includes(`--${name}`)

async function main() {
  const network = arg('network', 'base')!
  const env = (arg('env', 'production') as Env)!
  const withOnchain = hasFlag('onchain')

  const deploymentRoot =
    process.env.DEPLOYMENT_DIR ?? path.resolve(__dirname, '..', '..', 'deployment')
  if (!fs.existsSync(deploymentRoot)) {
    throw new Error(`deployment package not found at ${deploymentRoot} (set DEPLOYMENT_DIR to override)`)
  }

  console.log(`Generating graph: network=${network} env=${env} onchain=${withOnchain}`)
  const passA = buildConfigGraph(deploymentRoot, network, env)

  const file: GraphFile = {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    network,
    chainId: passA.chainId,
    env,
    onchain: { fetched: false },
    nodes: passA.nodes,
    edges: passA.edges,
  }

  if (withOnchain) {
    // Pass B wires in here (Phase 4). Kept config-only until then.
    console.warn('--onchain requested but Pass B not implemented yet; emitting config-only graph.')
  }

  const parsed = GraphFileSchema.parse(file)
  const outDir = path.resolve(__dirname, '..', 'data')
  fs.mkdirSync(outDir, { recursive: true })
  const outPath = path.join(outDir, `graph.${network}.${env}.json`)
  fs.writeFileSync(outPath, JSON.stringify(parsed, null, 2) + '\n')

  const counts = parsed.nodes.reduce<Record<string, number>>((a, n) => {
    a[n.type] = (a[n.type] ?? 0) + 1
    return a
  }, {})
  console.log(`Wrote ${outPath}`)
  console.log(`  nodes: ${parsed.nodes.length} ${JSON.stringify(counts)}`)
  console.log(`  edges: ${parsed.edges.length}`)
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})
