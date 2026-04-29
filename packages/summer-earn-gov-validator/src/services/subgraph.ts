import { GraphQLClient } from 'graphql-request'

import {
  CrossChainProposal,
  Proposal,
  ProposalWithCrossChain,
  SubgraphDelegate,
} from '@/types/governance'

const SUBGRAPH_ENDPOINTS = {
  base:
    process.env.NEXT_PUBLIC_BASE_SUBGRAPH_URL ||
    'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-base',
  arbitrum:
    process.env.NEXT_PUBLIC_ARBITRUM_SUBGRAPH_URL ||
    'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-arbitrum',
  sonic:
    process.env.NEXT_PUBLIC_SONIC_SUBGRAPH_URL ||
    'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-sonic',
  mainnet:
    process.env.NEXT_PUBLIC_MAINNET_SUBGRAPH_URL ||
    'https://subgraph.staging.oasisapp.dev/summer-protocol-gov',
}

const SATELLITE_SUBGRAPH_ENDPOINTS = Object.fromEntries(
  Object.entries(SUBGRAPH_ENDPOINTS).filter(([key]) => key !== 'base'),
)

const DELEGATES_QUERY = `
  query GetDelegates {
    delegates(first: 100, orderBy: votingPower, orderDirection: desc, where: {votingPower_gt: 0}) {
      id
      votingPower
      delegationsCount
    }
  }
`

const CROSS_CHAIN_PROPOSALS_QUERY = `
  query GetCrossChainProposals {
    crossChainProposals(first:1000) {
      id
      proposalId
      chainId
      status
      salt
      targets
      values
      calldatas
      eta
    }
  }
`

interface ProposalsResponse {
  proposals: Proposal[]
}

interface CrossChainProposalsResponse {
  crossChainProposals: CrossChainProposal[]
}

export async function fetchAllProposals(
  params: { isV1: boolean } = { isV1: false },
): Promise<ProposalWithCrossChain[]> {
  const { isV1 } = params
  const fetchOptions = { next: { revalidate: 60 } } as RequestInit
  const baseClient = new GraphQLClient(SUBGRAPH_ENDPOINTS.base, {
    fetch: (url, options) => fetch(url, { ...options, ...fetchOptions }),
  })
  let where = {}
  if (isV1) {
    where = { governor_not: '0x4ceee1b6289624d381383c1bb42b118d5f2c3274' }
  } else {
    where = { governor: '0x4ceee1b6289624d381383c1bb42b118d5f2c3274' }
  }
  // Update query to include new fields
  const ENHANCED_PROPOSALS_QUERY = `
    query GetProposals($where: Proposal_filter) {
      proposals(first:1000, orderBy: createdAt, orderDirection: desc, where: $where) {
        id
        governor
        targets
        values
        calldatas
        description
        descriptionHash
        status
        chains
        dstIds
        eta
        governor
        createdAt
        quorum
        forVotes
        againstVotes
        abstainVotes
        voteStart
        voteEnd
        votes(first: 100, orderBy: timestamp, orderDirection: desc, where:{votes_gt:0}) {
          id
          voter
          support
          votes
          reason
          timestamp
        }
      }
    }
  `

  const baseProposals = await baseClient.request<ProposalsResponse>(ENHANCED_PROPOSALS_QUERY, {
    where,
  })

  const allProposals: ProposalWithCrossChain[] = []
  const allCrossChainProposals: CrossChainProposal[] = []
  const crossChainProposalsPromises = Object.entries(SATELLITE_SUBGRAPH_ENDPOINTS).map(
    async ([chain, endpoint]) => {
      try {
        const client = new GraphQLClient(endpoint, {
          fetch: (url, options) => fetch(url, { ...options, ...fetchOptions }),
        })
        const result = await client.request<CrossChainProposalsResponse>(
          CROSS_CHAIN_PROPOSALS_QUERY,
        )
        return result.crossChainProposals
      } catch (error) {
        console.error(`Error fetching cross-chain proposals from ${chain}:`, error)
        return []
      }
    },
  )

  const results = await Promise.all(crossChainProposalsPromises)
  results.forEach((proposals: CrossChainProposal[]) => allCrossChainProposals.push(...proposals))

  for (const proposal of baseProposals.proposals) {
    const crossChainProposals: CrossChainProposal[] = []

    // Filter cross-chain proposals that match the dstIds of the base proposal
    const matchingProposals = allCrossChainProposals.filter((ccp: CrossChainProposal) =>
      proposal.dstIds?.includes(ccp.id),
    )

    crossChainProposals.push(...matchingProposals)

    allProposals.push({
      baseProposal: proposal,
      crossChainProposals,
    })
  }

  return allProposals
}

export async function fetchProposalWithCrossChainById(
  id: string,
  isV1: boolean = false,
): Promise<ProposalWithCrossChain | null> {
  try {
    const allProposals = await fetchAllProposals({ isV1 })
    const proposal = allProposals.find((p) => p.baseProposal.id === id)
    return proposal || null
  } catch (error) {
    console.error('Error fetching proposal with cross-chain data:', error)
    return null
  }
}

interface DelegatesResponse {
  delegates: SubgraphDelegate[]
}

export async function fetchDelegates(): Promise<SubgraphDelegate[]> {
  try {
    const client = new GraphQLClient(SUBGRAPH_ENDPOINTS.base)
    const result = await client.request<DelegatesResponse>(DELEGATES_QUERY)
    return result.delegates || []
  } catch (error) {
    console.error('Error fetching delegates:', error)
    return []
  }
}
