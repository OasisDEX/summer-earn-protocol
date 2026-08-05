'use cache'

import { cacheLife, cacheTag } from 'next/cache'

import { fetchAllProposals, fetchDelegates, fetchProposalById } from '@/services/subgraph'
import { ProposalWithCrossChain, SubgraphDelegate } from '@/types/governance'

export async function getProposalsCached(
  params: { isV1: boolean } = { isV1: false },
): Promise<ProposalWithCrossChain[]> {
  cacheLife({ stale: 60, revalidate: 120, expire: 600 })
  cacheTag('proposals', params.isV1 ? 'proposals:v1' : 'proposals:v2')
  return fetchAllProposals(params)
}

export async function getProposalByIdCached(
  id: string,
  isV1: boolean = false,
): Promise<ProposalWithCrossChain | null> {
  cacheLife({ stale: 60, revalidate: 120, expire: 600 })
  cacheTag('proposals', `proposal:${id}`, isV1 ? 'proposals:v1' : 'proposals:v2')
  return fetchProposalById(id, isV1)
}

export async function getDelegatesCached(): Promise<SubgraphDelegate[]> {
  cacheLife({ stale: 300, revalidate: 600, expire: 1800 })
  cacheTag('delegates')
  return fetchDelegates()
}
