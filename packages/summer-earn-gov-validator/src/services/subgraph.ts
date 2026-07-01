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
  hyperliquid:
    process.env.NEXT_PUBLIC_HYPERLIQUID_SUBGRAPH_URL ||
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

// Retry transient upstream failures (5xx / network) a couple of times. Without this a
// single subgraph 502 makes a proposal fetch return null, which then gets cached as a
// bogus "not found" for the cache window. GraphQL validation errors (4xx / 200-with-
// errors) are NOT retried — they won't recover.
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

// Fields shared by the list and detail queries. Individual votes are intentionally
// NOT included here: the list renders aggregate vote counts (forVotes/againstVotes/
// abstainVotes), so fetching up to 100 votes per proposal on the list is wasted work.
// The detail query adds the votes selection below.
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

// Fetch cross-chain proposals from every satellite subgraph in parallel. When `ids`
// is given, only those cross-chain proposals are requested (used for a single proposal
// so we don't pull every satellite's full list).
async function fetchCrossChainProposals(ids?: string[]): Promise<CrossChainProposal[]> {
  const where = ids ? { id_in: ids } : {}
  const promises = Object.entries(SATELLITE_SUBGRAPH_ENDPOINTS).map(async ([chain, endpoint]) => {
    try {
      const client = getSubgraphClient(endpoint)
      const result = await requestWithRetry<CrossChainProposalsResponse>(
        client,
        CROSS_CHAIN_PROPOSALS_QUERY,
        { where },
      )
      return result.crossChainProposals
    } catch (error) {
      console.error(`Error fetching cross-chain proposals from ${chain}:`, error)
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

  // Base proposals (without votes) and satellite cross-chain proposals are independent,
  // so fetch them concurrently.
  const [baseProposals, allCrossChainProposals] = await Promise.all([
    requestWithRetry<ProposalsResponse>(baseClient, LIST_PROPOSALS_QUERY, {
      where: governorWhere(isV1),
    }),
    fetchCrossChainProposals(),
  ])

  // Join cross-chain proposals to their base proposal by dstIds.
  return baseProposals.proposals.map((proposal) => ({
    baseProposal: proposal,
    crossChainProposals: allCrossChainProposals.filter((ccp) => proposal.dstIds?.includes(ccp.id)),
  }))
}

// Fetch a single proposal (with its votes) by id, plus only its own cross-chain
// proposals. Avoids pulling all ~1000 proposals + every satellite's full list just to
// render one detail page.
export async function fetchProposalById(id: string): Promise<ProposalWithCrossChain | null> {
  try {
    const baseClient = getSubgraphClient(SUBGRAPH_ENDPOINTS.base)
    const { proposal } = await requestWithRetry<SingleProposalResponse>(
      baseClient,
      SINGLE_PROPOSAL_QUERY,
      { id },
    )
    if (!proposal) return null

    const dstIds = proposal.dstIds ?? []
    // Only hit the satellite subgraphs when the proposal actually has cross-chain targets.
    const allCrossChain = dstIds.length > 0 ? await fetchCrossChainProposals(dstIds) : []
    const crossChainProposals = allCrossChain.filter((ccp) => dstIds.includes(ccp.id))

    return { baseProposal: proposal, crossChainProposals }
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
    const client = getSubgraphClient(SUBGRAPH_ENDPOINTS.base)
    const result = await requestWithRetry<DelegatesResponse>(client, DELEGATES_QUERY)
    return result.delegates || []
  } catch (error) {
    console.error('Error fetching delegates:', error)
    return []
  }
}
