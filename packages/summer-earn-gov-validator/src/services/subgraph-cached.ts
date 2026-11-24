'use cache'

import { cacheLife, cacheTag } from 'next/cache'

import * as rpcSource from '@/services/rpc-governance'
import * as subgraphSource from '@/services/subgraph'
import { ProposalWithCrossChain, SubgraphDelegate } from '@/types/governance'

// Proposals come from on-chain governor logs by default (no subgraph dependency; see
// services/rpc-governance.ts). Set GOV_DATA_SOURCE=subgraph to switch back. Delegates
// always use the subgraph: ranking delegates needs the token's full DelegateVotesChanged
// history, which a bounded log window cannot provide (fetchDelegates degrades to []).
function isSubgraphSource() {
  return process.env.GOV_DATA_SOURCE === 'subgraph'
}

// In rpc mode one log scan serves both governors and every detail page.
export async function getGovernanceScanCached(): Promise<{
  v1: ProposalWithCrossChain[]
  v2: ProposalWithCrossChain[]
}> {
  // A cold public-RPC scan can take minutes (Base makes ~5 blocks/s), so keep serving
  // the last scan for up to a day and refresh it in the background every 5 minutes.
  cacheLife({ stale: 60, revalidate: 300, expire: 86_400 })
  cacheTag('proposals', 'proposals:v1', 'proposals:v2')
  return rpcSource.fetchAllGovernanceProposals()
}

export async function getProposalsCached(
  params: { isV1: boolean } = { isV1: false },
): Promise<ProposalWithCrossChain[]> {
  cacheLife({ stale: 60, revalidate: 120, expire: 600 })
  cacheTag('proposals', params.isV1 ? 'proposals:v1' : 'proposals:v2')
  if (isSubgraphSource()) return subgraphSource.fetchAllProposals(params)
  const scan = await getGovernanceScanCached()
  return params.isV1 ? scan.v1 : scan.v2
}

export async function getProposalByIdCached(
  id: string,
  isV1: boolean = false,
): Promise<ProposalWithCrossChain | null> {
  cacheLife({ stale: 60, revalidate: 120, expire: 600 })
  cacheTag('proposals', `proposal:${id}`, isV1 ? 'proposals:v1' : 'proposals:v2')
  if (isSubgraphSource()) return subgraphSource.fetchProposalById(id, isV1)
  const scan = await getGovernanceScanCached()
  return (isV1 ? scan.v1 : scan.v2).find((p) => p.baseProposal.id === id) ?? null
}

export async function getDelegatesCached(): Promise<SubgraphDelegate[]> {
  cacheTag('delegates')
  try {
    const delegates = await subgraphSource.fetchDelegates()
    cacheLife({ stale: 300, revalidate: 600, expire: 1800 })
    return delegates
  } catch (error) {
    // An unreachable subgraph must not fail the page (or the build's prerender):
    // show an empty list and retry soon.
    console.error('Error fetching delegates from subgraph:', error)
    cacheLife({ stale: 30, revalidate: 60, expire: 300 })
    return []
  }
}
