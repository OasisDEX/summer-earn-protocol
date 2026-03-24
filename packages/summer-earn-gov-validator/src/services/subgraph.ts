import { GraphQLClient } from 'graphql-request'

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

const PROPOSALS_QUERY = `
  query GetProposals {
    proposals(first:1000, orderBy: createdAt, orderDirection: desc, where: {governor: "0x4ceee1b6289624d381383c1bb42b118d5f2c3274"}) {
      id
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

export interface Vote {
  id: string
  voter: string
  support: number // 0: Against, 1: For, 2: Abstain
  weight: string
  reason: string
  timestamp: string
}

export interface Proposal {
  id: string
  targets: string[]
  values: string[]
  calldatas: string[]
  description: string
  descriptionHash: string
  status: string
  chains: string[]
  dstIds: string[]
  eta: string
  createdAt: string
  quorum: string
  forVotes: string
  againstVotes: string
  abstainVotes: string
  votes: Vote[]
}

export interface CrossChainProposal {
  id: string
  proposalId: string
  chainId: string
  status: string
  salt: string
  targets: string[]
  values: string[]
  calldatas: string[]
  eta: string
}

export interface ProposalWithCrossChain {
  baseProposal: Proposal
  crossChainProposals: CrossChainProposal[]
}

interface ProposalsResponse {
  proposals: Proposal[]
}

interface CrossChainProposalsResponse {
  crossChainProposals: CrossChainProposal[]
}

// Mock votes for development
const MOCK_VOTES: Vote[] = [
  {
    id: 'v1',
    voter: 'vitalik.eth',
    support: 1,
    weight: '1200000000000000000000000', // 1.2M
    reason: 'Strategic alignment with the DAO goals.',
    timestamp: (Math.floor(Date.now() / 1000) - 7200).toString(), // 2h ago
  },
  {
    id: 'v2',
    voter: 'aeyakovenko.eth',
    support: 1,
    weight: '850000000000000000000000', // 850k
    reason: 'Supporting mainnet expansion.',
    timestamp: (Math.floor(Date.now() / 1000) - 18000).toString(), // 5h ago
  },
  {
    id: 'v3',
    voter: 'whale.eth',
    support: 0,
    weight: '420000000000000000000000', // 420k
    reason: 'Concerns about high risk parameters.',
    timestamp: (Math.floor(Date.now() / 1000) - 28800).toString(), // 8h ago
  },
  {
    id: 'v4',
    voter: 'anon.eth',
    support: 2,
    weight: '120000000000000000000000', // 120k
    reason: 'Waiting for more information.',
    timestamp: (Math.floor(Date.now() / 1000) - 43200).toString(), // 12h ago
  },
]

export async function fetchAllProposals(): Promise<ProposalWithCrossChain[]> {
  const fetchOptions = { next: { revalidate: 60 } } as RequestInit
  const baseClient = new GraphQLClient(SUBGRAPH_ENDPOINTS.base, {
    fetch: (url, options) => fetch(url, { ...options, ...fetchOptions }),
  })

  // Update query to include new fields
  const ENHANCED_PROPOSALS_QUERY = `
    query GetProposals {
      proposals(first:1000, orderBy: createdAt, orderDirection: desc, where: {governor: "0x4ceee1b6289624d381383c1bb42b118d5f2c3274"}) {
        id
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
        votes(first: 10, orderBy: timestamp, orderDirection: desc) {
          id
          voter
          support
          weight
          reason
          timestamp
        }
      }
    }
  `

  const baseProposals = await baseClient.request<ProposalsResponse>(ENHANCED_PROPOSALS_QUERY)

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
      proposal.dstIds.includes(ccp.id),
    )

    crossChainProposals.push(...matchingProposals)

    // Add mock data if votes are empty (for development)
    if (!proposal.votes || proposal.votes.length === 0) {
      proposal.votes = MOCK_VOTES
      proposal.forVotes = '2050000000000000000000000'
      proposal.againstVotes = '420000000000000000000000'
      proposal.abstainVotes = '120000000000000000000000'
      proposal.quorum = '1000000000000000000000000'
    }

    allProposals.push({
      baseProposal: proposal,
      crossChainProposals,
    })
  }

  return allProposals
}

export async function fetchProposalWithCrossChainById(
  id: string,
): Promise<ProposalWithCrossChain | null> {
  try {
    const allProposals = await fetchAllProposals()
    const proposal = allProposals.find((p) => p.baseProposal.id === id)
    return proposal || null
  } catch (error) {
    console.error('Error fetching proposal with cross-chain data:', error)
    return null
  }
}

export interface SubgraphDelegate {
  id: string
  votingPower: string
  delegationsCount: number
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
