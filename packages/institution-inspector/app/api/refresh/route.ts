import path from 'node:path'
import { NextResponse } from 'next/server'
import type { GraphFile } from '@/lib/graph-schema'
import { augmentOnchain } from '@/lib/onchain/augment'
import { buildConfigGraph, type Env } from '@/scripts/build-config-graph'

// Re-run Pass A (config + Ignition) + Pass B (on-chain) live for one network/env.
// Local-first: reads the sibling deployment package from disk, so it only works when
// running against a checkout (not a static hosted build).
//
// On a static export build (NEXT_PUBLIC_STATIC_EXPORT=1) there is no server runtime, so
// this route is prerendered to a constant "disabled" response — the deployment package
// isn't shipped to hosting anyway. The UI hides the refresh control in that mode.
const STATIC_EXPORT = process.env.NEXT_PUBLIC_STATIC_EXPORT === '1'

export const runtime = 'nodejs'
export const dynamic = STATIC_EXPORT ? 'force-static' : 'force-dynamic'

export async function GET(req: Request) {
  if (STATIC_EXPORT) {
    // Prerendered at build time on the static export; the UI hides the refresh control here.
    return NextResponse.json({ error: 'On-chain refresh is unavailable on the static build.' })
  }
  const { searchParams } = new URL(req.url)
  const network = searchParams.get('network') ?? 'base'
  const env = (searchParams.get('env') ?? 'production') as Env

  try {
    const deploymentRoot =
      process.env.DEPLOYMENT_DIR ?? path.resolve(process.cwd(), '..', 'deployment')
    const passA = buildConfigGraph(deploymentRoot, network, env)
    const onchain = await augmentOnchain({
      network,
      nodes: passA.nodes,
      edges: passA.edges,
      pamByInstitution: passA.pamByInstitution,
      registries: passA.registries,
    })
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
    return NextResponse.json(file)
  } catch (e) {
    return NextResponse.json({ error: e instanceof Error ? e.message : String(e) }, { status: 500 })
  }
}
