import fs from 'node:fs'
import path from 'node:path'
import { GraphFileSchema, type GraphFile } from '../lib/graph-schema'
import { augmentOnchain } from '../lib/onchain/augment'
import { buildConfigGraph, type Env } from './build-config-graph'

/**
 * Generate the normalized inspection graph for a network/env.
 *
 *   pnpm generate -- --network base --env production [--onchain]
 *
 * Pass A (config + Ignition) always runs. Pass B (on-chain) is gated behind --onchain.
 */

export function defaultDeploymentRoot(): string {
  return process.env.DEPLOYMENT_DIR ?? path.resolve(__dirname, '..', '..', 'deployment')
}

/** Build (and optionally on-chain-verify) one graph and write it to data/. Skips empty graphs. */
export async function generate(
  network: string,
  env: Env,
  withOnchain: boolean,
  deploymentRoot = defaultDeploymentRoot(),
): Promise<{ written: boolean; nodes: number }> {
  if (!fs.existsSync(deploymentRoot)) {
    throw new Error(`deployment package not found at ${deploymentRoot} (set DEPLOYMENT_DIR to override)`)
  }

  const passA = buildConfigGraph(deploymentRoot, network, env)
  const institutions = passA.nodes.filter((n) => n.type === 'institution').length
  if (institutions === 0) {
    console.log(`• ${network}/${env}: no institutions for this network/env — skipped`)
    return { written: false, nodes: 0 }
  }

  let onchain = { fetched: false } as Awaited<ReturnType<typeof augmentOnchain>>
  if (withOnchain) {
    onchain = await augmentOnchain({
      network,
      nodes: passA.nodes,
      edges: passA.edges,
      pamByInstitution: passA.pamByInstitution,
      registries: passA.registries,
    })
  }

  const file: GraphFile = {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    network,
    chainId: passA.chainId,
    env,
    onchain,
    nodes: passA.nodes,
    edges: passA.edges,
  }
  const parsed = GraphFileSchema.parse(file)
  const outDir = path.resolve(__dirname, '..', 'data')
  fs.mkdirSync(outDir, { recursive: true })
  const outPath = path.join(outDir, `graph.${network}.${env}.json`)
  fs.writeFileSync(outPath, JSON.stringify(parsed, null, 2) + '\n')

  const onchainNote = withOnchain ? (onchain.fetched ? `on-chain @ ${onchain.blockNumber}` : 'on-chain failed → config-only') : 'config-only'
  console.log(`✓ ${network}/${env}: ${parsed.nodes.length} nodes, ${parsed.edges.length} edges (${onchainNote})`)
  return { written: true, nodes: parsed.nodes.length }
}

function arg(name: string, fallback?: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`)
  if (i !== -1 && process.argv[i + 1] && !process.argv[i + 1].startsWith('--')) return process.argv[i + 1]
  return fallback
}
const hasFlag = (name: string) => process.argv.includes(`--${name}`)

async function main() {
  const network = arg('network', 'base')!
  const env = (arg('env', 'production') as Env)!
  await generate(network, env, hasFlag('onchain'))
}

if (require.main === module) {
  main().catch((e) => {
    console.error(e)
    process.exit(1)
  })
}
