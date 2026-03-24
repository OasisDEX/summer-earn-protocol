/**
 * MOCK_DATA: Proposal list - Replace with subgraph query
 * TODO: Replace with actual fetchProposals() call from subgraph.ts
 */

export interface Proposal {
  id: string
  status: 'Active' | 'Executed' | 'Queued' | 'Defeated'
  chain: string
  title: string
  description: string
  quorumProgress: number
  timeRemaining: string
  forVotes: number
  againstVotes: number
  abstainVotes: number
  targets: string[]
  values: string[]
  calldatas: string[]
}

export const MOCK_PROPOSALS: Proposal[] = [
  {
    id: 'GIP-142',
    status: 'Active',
    chain: 'Ethereum',
    title: 'Allocate 2.5M GLCR to Liquidity Incentive Program v2',
    description:
      'Integrate Sonic Network validators into the core yield engine to maximize native emissions and provide better yields for liquidity providers.',
    quorumProgress: 65,
    timeRemaining: '2d 14h',
    forVotes: 65,
    againstVotes: 25,
    abstainVotes: 10,
    targets: ['0xBE5A4DD68c3526F32B454fE28C9909cA0601e9Fa'],
    values: ['0'],
    calldatas: [
      '0x9c0f30a100000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000002736770680000000000000000000000000000000000000000000000000000000000',
    ],
  },
  {
    id: 'GIP-141',
    status: 'Executed',
    chain: 'Base',
    title: 'Upgrade Treasury Allocation Strategy',
    description:
      'Diversify treasury holdings across multiple chains and increase stablecoin allocation to reduce volatility.',
    quorumProgress: 100,
    timeRemaining: 'Executed',
    forVotes: 78,
    againstVotes: 12,
    abstainVotes: 10,
    targets: ['0x447BF9d1485ABDc4C1778025DfdfbE8b894C3796'],
    values: ['0'],
    calldatas: ['0x4ce3f42300000000000000000000000000000000000000000000000000000000000003c00'],
  },
  {
    id: 'GIP-140',
    status: 'Queued',
    chain: 'Arbitrum',
    title: 'Add New Collateral Types',
    description:
      'Support additional collateral types for the lending protocol including rETH and cbETH.',
    quorumProgress: 100,
    timeRemaining: 'Queued',
    forVotes: 82,
    againstVotes: 15,
    abstainVotes: 3,
    targets: ['0x447BF9d1485ABDc4C1778025DfdfbE8b894C3796'],
    values: ['0'],
    calldatas: [
      '0x8f2839700000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000',
    ],
  },
  {
    id: 'GIP-139',
    status: 'Active',
    chain: 'Sonic',
    title: 'Extend Reward Distribution Period',
    description:
      'Extend the current reward distribution period by 6 months to ensure continuous incentivization.',
    quorumProgress: 45,
    timeRemaining: '5d 8h',
    forVotes: 45,
    againstVotes: 30,
    abstainVotes: 25,
    targets: [],
    values: [],
    calldatas: [],
  },
  {
    id: 'GIP-138',
    status: 'Defeated',
    chain: 'Ethereum',
    title: 'Reduce Quorum Threshold',
    description:
      'Proposal to reduce the quorum threshold from 50% to 30% for faster governance execution.',
    quorumProgress: 100,
    timeRemaining: 'Defeated',
    forVotes: 35,
    againstVotes: 55,
    abstainVotes: 10,
    targets: [],
    values: [],
    calldatas: [],
  },
]

/**
 * MOCK_DATA: Delegate list - Replace with delegate registry
 * TODO: Replace with actual fetchDelegates() call
 */

export interface Delegate {
  ensName: string
  address: string
  votingPower: string
  proposalsVoted: number
}

export const MOCK_DELEGATES: Delegate[] = [
  {
    ensName: 'glacier.eth',
    address: '0x1234abcd5678efgh9012ijkl3456mnop',
    votingPower: '1.2M gGLCR',
    proposalsVoted: 15,
  },
  {
    ensName: 'validatormax.eth',
    address: '0xabcd1234efgh5678ijkl9012mnop3456',
    votingPower: '850K gGLCR',
    proposalsVoted: 12,
  },
  {
    ensName: 'yieldfarmer.eth',
    address: '0x7890qrst1234uvwx5678yzab9012cdef',
    votingPower: '620K gGLCR',
    proposalsVoted: 8,
  },
  {
    ensName: 'treasurydao.eth',
    address: '0xdefg5678hijk9012lmno3456pqrs7890',
    votingPower: '450K gGLCR',
    proposalsVoted: 22,
  },
  {
    ensName: 'liquidity.eth',
    address: '0x9012uvwx3456abcd7890efgh1234ijkl',
    votingPower: '320K gGLCR',
    proposalsVoted: 5,
  },
]

/**
 * MOCK_DATA: Treasury holdings - Replace with API/subgraph
 * TODO: Replace with fetchTreasuryBalances() call
 */

export interface TreasuryHolding {
  token: string
  symbol: string
  chain: string
  balance: string
  value: string
}

export const MOCK_TREASURY = {
  totalValue: '$42,892,105.42',
  change24h: '+2.4%',
  holdings: [
    {
      token: 'Ethereum',
      symbol: 'ETH',
      chain: 'Mainnet',
      balance: '12,450.00 ETH',
      value: '$30,147,052.50',
    },
    {
      token: 'USD Coin',
      symbol: 'USDC',
      chain: 'Base',
      balance: '8,500,000 USDC',
      value: '$8,500,000.00',
    },
    {
      token: 'Dai',
      symbol: 'DAI',
      chain: 'Arbitrum',
      balance: '3,200,000 DAI',
      value: '$3,200,000.00',
    },
    {
      token: 'Wrapped Ether',
      symbol: 'WETH',
      chain: 'Sonic',
      balance: '250 WETH',
      value: '$605,052.92',
    },
    {
      token: 'USDT',
      symbol: 'USDT',
      chain: 'Mainnet',
      balance: '440,000 USDT',
      value: '$440,000.00',
    },
  ] as TreasuryHolding[],
}

/**
 * MOCK_DATA: Voting results - Replace with actual query
 * TODO: Replace with fetchProposalVotes() call
 */

export interface VotingResults {
  for: number
  against: number
  abstain: number
}

export const getMockVotingResults = (proposalId: string): VotingResults => {
  const proposal = MOCK_PROPOSALS.find((p) => p.id === proposalId)
  if (proposal) {
    return {
      for: proposal.forVotes,
      against: proposal.againstVotes,
      abstain: proposal.abstainVotes,
    }
  }
  return { for: 0, against: 0, abstain: 0 }
}

/**
 * MOCK_DATA: Single proposal - Replace with subgraph query
 * TODO: Replace with fetchProposalById() call
 */

export const getMockProposalById = (id: string): Proposal | undefined => {
  return MOCK_PROPOSALS.find((p) => p.id === id)
}
