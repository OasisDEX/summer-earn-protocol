import { GraphQLClient } from 'graphql-request'

const SUBGRAPH_ENDPOINTS = {
  base:
    process.env.NEXT_PUBLIC_BASE_SUBGRAPH_URL ||
    'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-base',
  //   arbitrum: process.env.NEXT_PUBLIC_ARBITRUM_SUBGRAPH_URL || 'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-arbitrum',
  //   sonic: process.env.NEXT_PUBLIC_SONIC_SUBGRAPH_URL || 'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-sonic',
  mainnet:
    process.env.NEXT_PUBLIC_MAINNET_SUBGRAPH_URL ||
    'https://subgraph.staging.oasisapp.dev/summer-protocol-gov',
}

const PROPOSALS_QUERY = `
  query GetProposals {
    proposals(first:1000) {
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
    }
  }
`

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

export async function fetchAllProposals(): Promise<ProposalWithCrossChain[]> {
  const baseClient = new GraphQLClient(SUBGRAPH_ENDPOINTS.base)
  const baseProposals = await baseClient.request<ProposalsResponse>(PROPOSALS_QUERY)

  const allProposals: ProposalWithCrossChain[] = []
  const allCrossChainProposals: CrossChainProposal[] = []
  for (const [chain, endpoint] of Object.entries(SUBGRAPH_ENDPOINTS)) {
    const client = new GraphQLClient(endpoint)
    const result = await client.request<CrossChainProposalsResponse>(CROSS_CHAIN_PROPOSALS_QUERY)
    allCrossChainProposals.push(...result.crossChainProposals)
  }
  console.log(allCrossChainProposals.map((p) => p.id))
  console.log(baseProposals.proposals.map((p) => p.dstIds))
  for (const proposal of baseProposals.proposals) {
    const crossChainProposals: CrossChainProposal[] = []
    // Fetch cross-chain proposals from all chains

    // Filter cross-chain proposals that match the dstIds of the base proposal
    const matchingProposals = allCrossChainProposals.filter((ccp: CrossChainProposal) =>
      proposal.dstIds.includes(ccp.id),
    )

    crossChainProposals.push(...matchingProposals)

    allProposals.push({
      baseProposal: proposal,
      crossChainProposals,
    })
  }

  return allProposals
}
