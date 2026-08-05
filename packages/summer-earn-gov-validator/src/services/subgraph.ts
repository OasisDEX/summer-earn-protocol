import { GraphQLClient } from 'graphql-request'

import {
  CrossChainProposal,
  Proposal,
  ProposalWithCrossChain,
  SubgraphDelegate,
} from '@/types/governance'

const SUBGRAPH_ENDPOINTS = {
  base:
    process.env.BASE_SUBGRAPH_URL ||
    'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-base',
  arbitrum:
    process.env.ARBITRUM_SUBGRAPH_URL ||
    'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-arbitrum',
  sonic:
    process.env.SONIC_SUBGRAPH_URL ||
    'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-sonic',
  mainnet:
    process.env.MAINNET_SUBGRAPH_URL ||
    'https://subgraph.staging.oasisapp.dev/summer-protocol-gov',
  hyperliquid:
    process.env.HYPERLIQUID_SUBGRAPH_URL ||
    'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-hyperliquid',
}

const SATELLITE_SUBGRAPH_ENDPOINTS = Object.fromEntries(
  Object.entries(SUBGRAPH_ENDPOINTS).filter(([key]) => key !== 'base'),
)

const HUB_GOVERNOR = '0x4ceee1b6289624d381383c1bb42b118d5f2c3274'

// Reuse one GraphQL client per endpoint instead of constructing a new one per call.
const graphqlClients: Record<string, GraphQLClient> = {}
function getSubgraphClient(endpoint: string): GraphQLClient {
  return (graphqlClients[endpoint] ??= new GraphQLClient(endpoint))
}

// Retry transient upstream failures (5xx / network) a couple of times.
async function requestWithRetry<T>(
  client: GraphQLClient,
  query: string,
  variables?: Record<string, unknown>,
  retries = 2,
): Promise<T> {
  let lastError: unknown
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      return await client.request<T>(query, variables)
    } catch (error) {
      lastError = error
      const status = (error as { response?: { status?: number } })?.response?.status
      const transient = status === undefined || status >= 500
      if (attempt === retries || !transient) break
      await new Promise((resolve) => setTimeout(resolve, 300 * (attempt + 1)))
    }
  }
  throw lastError
}

const DELEGATES_QUERY = `
  query GetDelegates {
    delegates(first: 100, orderBy: votingPower, orderDirection: desc, where: {votingPower_gt: 0}) {
      id
      votingPower
      delegationsCount
    }
  }
`

const PROPOSAL_FIELDS = `
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
  createdAt
  quorum
  forVotes
  againstVotes
  abstainVotes
  voteStart
  voteEnd
`

const VOTES_FIELD = `
  votes(first: 100, orderBy: timestamp, orderDirection: desc, where: { votes_gt: 0 }) {
    id
    voter
    support
    votes
    reason
    timestamp
  }
`

const LIST_PROPOSALS_QUERY = `
  query GetProposals($where: Proposal_filter) {
    proposals(first: 1000, orderBy: createdAt, orderDirection: desc, where: $where) {
      ${PROPOSAL_FIELDS}
    }
  }
`

const SINGLE_PROPOSAL_QUERY = `
  query GetProposal($id: ID!) {
    proposal(id: $id) {
      ${PROPOSAL_FIELDS}
      ${VOTES_FIELD}
    }
  }
`

const CROSS_CHAIN_PROPOSALS_QUERY = `
  query GetCrossChainProposals($where: CrossChainProposal_filter) {
    crossChainProposals(first: 1000, where: $where) {
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

interface SingleProposalResponse {
  proposal: Proposal | null
}

interface CrossChainProposalsResponse {
  crossChainProposals: CrossChainProposal[]
}

function governorWhere(isV1: boolean) {
  return isV1 ? { governor_not: HUB_GOVERNOR } : { governor: HUB_GOVERNOR }
}

// Fetch cross-chain proposals from every satellite subgraph in parallel with detailed per-chain timing.
async function fetchCrossChainProposals(ids?: string[]): Promise<CrossChainProposal[]> {
  const where = ids ? { id_in: ids } : {}
  const chainTimings: Record<string, number> = {}

  const promises = Object.entries(SATELLITE_SUBGRAPH_ENDPOINTS).map(async ([chain, endpoint]) => {
    const start = performance.now()
    try {
      const client = getSubgraphClient(endpoint)
      const result = await requestWithRetry<CrossChainProposalsResponse>(
        client,
        CROSS_CHAIN_PROPOSALS_QUERY,
        { where },
      )
      const duration = Math.round(performance.now() - start)
      chainTimings[chain] = duration
      return result.crossChainProposals
    } catch (error) {
      const duration = Math.round(performance.now() - start)
      chainTimings[chain] = duration
      console.error(`Error fetching cross-chain proposals from ${chain} (${duration}ms):`, error)
      return []
    }
  })

  const results = await Promise.all(promises)
  return results.flat()
}

export async function fetchAllProposals(
  params: { isV1: boolean } = { isV1: false },
): Promise<ProposalWithCrossChain[]> {
  const { isV1 } = params
  const baseClient = getSubgraphClient(SUBGRAPH_ENDPOINTS.base)

  const [baseProposals, allCrossChainProposals] = await Promise.all([
    requestWithRetry<ProposalsResponse>(baseClient, LIST_PROPOSALS_QUERY, {
      where: governorWhere(isV1),
    }),
    fetchCrossChainProposals(),
  ])

  return baseProposals.proposals.map((proposal) => ({
    baseProposal: proposal,
    crossChainProposals: allCrossChainProposals.filter((ccp) => proposal.dstIds?.includes(ccp.id)),
  }))
}

export async function fetchProposalById(
  id: string,
  isV1: boolean = false,
): Promise<ProposalWithCrossChain | null> {
  const baseClient = getSubgraphClient(SUBGRAPH_ENDPOINTS.base)
  const { proposal } = await requestWithRetry<SingleProposalResponse>(
    baseClient,
    SINGLE_PROPOSAL_QUERY,
    { id },
  )

  if (!proposal) {
    return null
  }

  const isHub = proposal.governor?.toLowerCase() === HUB_GOVERNOR
  if (isV1 === isHub) {
    return null
  }

  const dstIds = proposal.dstIds ?? []
  let allCrossChain: CrossChainProposal[] = []

  if (dstIds.length > 0) {
    allCrossChain = await fetchCrossChainProposals(dstIds)
  }

  const crossChainProposals = allCrossChain.filter((ccp) => dstIds.includes(ccp.id))

  return { baseProposal: proposal, crossChainProposals }
}

interface DelegatesResponse {
  delegates: SubgraphDelegate[]
}

export async function fetchDelegates(): Promise<SubgraphDelegate[]> {
  const client = getSubgraphClient(SUBGRAPH_ENDPOINTS.base)
  const result = await requestWithRetry<DelegatesResponse>(client, DELEGATES_QUERY)
  return result.delegates || []
}
