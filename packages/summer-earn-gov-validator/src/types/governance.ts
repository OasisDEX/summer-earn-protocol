import { Hex } from 'viem'

export interface AbiOutput {
  name: string
  type: string
  components?: AbiOutput[]
  internalType?: string
}

export interface AbiInput {
  name: string
  type: string
  components?: AbiInput[]
  internalType?: string
}

export interface AbiItem {
  name?: string
  type: string
  inputs?: AbiInput[]
  outputs?: AbiOutput[]
  stateMutability?: string
}

export interface ProposalAction {
  id: string
  chainId: string
  target: string
  abi: AbiItem[]
  method: string
  args: Record<string, unknown>
  isValid: boolean
  /** Pre-encoded calldata from imported proposal JSON (bypasses ABI encoding) */
  rawCalldata?: string
  /** Raw value in wei from imported proposal JSON */
  rawValue?: string
}

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
export type SubgraphProposalStatus = 'Pending' | 'Queued' | 'Executed' | 'Canceled'

export interface Proposal {
  id: string
  governor: string
  targets: string[]
  values: string[]
  calldatas: string[]
  description: string
  descriptionHash: string
  status: SubgraphProposalStatus
  chains: string[]
  dstIds?: string[]
  eta: string
  createdAt: string
  quorum: string
  forVotes: string
  againstVotes: string
  abstainVotes: string
  votes: Vote[]
  voteStart: string
  voteEnd: string
  salt: string
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
  // CuriaLab analytics (participation metrics + forum PRS); absent when the Curia
  // API is unconfigured or has no data for this delegate.
  curia?: CuriaDelegateStats
}

export interface CuriaDelegateStats {
  prsScore: number | null
  votesCast: number
  proposalsCount: number
  recentVotes: number
  delegatorCount: number
  percentOfVotingPower: number
}

export interface SubgraphDelegate {
  id: string
  votingPower: string
  delegationsCount: number
}
export type FinalStatus =
  | 'Active'
  | 'Pending'
  | 'Executed'
  | 'Queued'
  | 'Defeated'
  | 'Executed on Hub'
  | 'Succeeded'
  | 'Canceled'

// Transform subgraph proposal to our format
export interface TransformedProposal {
  id: string
  displayId: string | null
  status: FinalStatus
  chain: string
  title: string
  description: string
  descriptionHash: Hex
  quorumProgress: number
  timeRemaining: number
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
  governor: string
  createdAt: string
}
