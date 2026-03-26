export interface Vote {
  id: string
  voter: string
  support: number // 0: Against, 1: For, 2: Abstain
  votes: string
  reason: string
  timestamp: string
}

export interface VoterMetadata {
  name: string
  picture: string | null
  twitter: string | null
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
  dstIds?: string[]
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

export interface Delegate {
  name: string
  address: string
  votingPower: string
  proposalsVoted: number
  bio?: string
  picture?: string | null
  twitter?: string
  isPrioritized?: boolean
}

export interface SubgraphDelegate {
  id: string
  votingPower: string
  delegationsCount: number
}

// Transform subgraph proposal to our format
export interface TransformedProposal {
  id: string
  displayId: string | null
  status:
    | 'Active'
    | 'Executed'
    | 'Queued'
    | 'Defeated'
    | 'Executed on Hub'
    | 'Succeeded'
    | 'Canceled'
  chain: string
  title: string
  description: string
  quorumProgress: number
  timeRemaining: string
  quorumReached: boolean
  forVotes: number
  againstVotes: number
  abstainVotes: number
  forPercent: number
  againstPercent: number
  abstainPercent: number
  quorum: number
  votes: Vote[]
  targets: string[]
  values: string[]
  calldatas: string[]
  eta: string
}
