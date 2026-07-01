'use cache'

import { cacheLife, cacheTag } from 'next/cache'

import { fetchAllProposals, fetchDelegates, fetchProposalById } from '@/services/subgraph'
import { ProposalWithCrossChain, SubgraphDelegate } from '@/types/governance'

// Proposals change infrequently and the `/api/revalidate` route can purge the
// `proposals` tag on demand, so we serve from cache for a long window and revalidate
// in the background (stale-while-revalidate) rather than blocking on the subgraph.
export async function getProposalsCached(
  params: { isV1: boolean } = { isV1: false },
): Promise<ProposalWithCrossChain[]> {
  cacheLife({ stale: 300, revalidate: 900, expire: 3600 })
  cacheTag('proposals', params.isV1 ? 'proposals:v1' : 'proposals:v2')
  return fetchAllProposals(params)
}

export async function getProposalByIdCached(
  id: string,
  isV1: boolean = false,
): Promise<ProposalWithCrossChain | null> {
  cacheLife({ stale: 300, revalidate: 900, expire: 3600 })
  cacheTag('proposals', `proposal:${id}`, isV1 ? 'proposals:v1' : 'proposals:v2')
  return fetchProposalById(id)
}

export async function getDelegatesCached(): Promise<SubgraphDelegate[]> {
  cacheLife('hours')
  cacheTag('delegates')
  return fetchDelegates()
}
