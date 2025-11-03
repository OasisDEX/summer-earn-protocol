import { useAccount, useReadContract, useReadContracts } from 'wagmi'

import config from '../config/index.json'

const GOVERNOR_ABI = [
  {
    inputs: [{ name: 'proposalId', type: 'uint256' }],
    name: 'proposalVotes',
    outputs: [
      { name: 'againstVotes', type: 'uint256' },
      { name: 'forVotes', type: 'uint256' },
      { name: 'abstainVotes', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { name: 'proposalId', type: 'uint256' },
      { name: 'account', type: 'address' },
    ],
    name: 'hasVoted',
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

const SUMMER_TOKEN_ABI = [
  {
    inputs: [{ name: 'account', type: 'address' }],
    name: 'getVotes',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

export interface ProposalVotes {
  againstVotes: bigint
  forVotes: bigint
  abstainVotes: bigint
}

export interface UserVotingInfo {
  votingPower: bigint
  hasVoted: boolean
}

export function useProposalVoting(proposalId: string | undefined) {
  const { address } = useAccount()

  const governorAddress = config.base?.deployedContracts?.gov?.summerGovernor?.address
  const tokenAddress = config.base?.deployedContracts?.gov?.summerToken?.address

  // Get proposal votes
  const { data: proposalVotes, refetch: refetchVotes } = useReadContract({
    address: governorAddress as `0x${string}`,
    abi: GOVERNOR_ABI,
    functionName: 'proposalVotes',
    args: proposalId ? [BigInt(proposalId)] : undefined,
    chainId: 8453, // Base chain
    query: {
      enabled: !!proposalId && !!governorAddress,
    },
  })

  // Get user's voting power
  const { data: votingPower } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: SUMMER_TOKEN_ABI,
    functionName: 'getVotes',
    args: address ? [address] : undefined,
    chainId: 8453, // Base chain
    query: {
      enabled: !!address && !!tokenAddress,
    },
  })

  // Check if user has voted
  const { data: hasVoted, refetch: refetchHasVoted } = useReadContract({
    address: governorAddress as `0x${string}`,
    abi: GOVERNOR_ABI,
    functionName: 'hasVoted',
    args: proposalId && address ? [BigInt(proposalId), address] : undefined,
    chainId: 8453, // Base chain
    query: {
      enabled: !!proposalId && !!address && !!governorAddress,
    },
  })

  const votes: ProposalVotes | undefined = proposalVotes
    ? {
        againstVotes: proposalVotes[0],
        forVotes: proposalVotes[1],
        abstainVotes: proposalVotes[2],
      }
    : undefined

  const userInfo: UserVotingInfo | undefined =
    votingPower !== undefined && hasVoted !== undefined
      ? {
          votingPower,
          hasVoted,
        }
      : undefined

  const refetch = () => {
    refetchVotes()
    refetchHasVoted()
  }

  return {
    votes,
    userInfo,
    refetch,
    isLoading: !votes || !userInfo,
  }
}

export function useMultipleProposalVoting(proposalIds: string[]) {
  const { address } = useAccount()

  const governorAddress = config.base?.deployedContracts?.gov?.summerGovernor?.address
  const tokenAddress = config.base?.deployedContracts?.gov?.summerToken?.address

  // Prepare contracts for batch reading
  const proposalContracts = proposalIds.flatMap((proposalId) => [
    {
      address: governorAddress as `0x${string}`,
      abi: GOVERNOR_ABI,
      functionName: 'proposalVotes' as const,
      args: [BigInt(proposalId)],
      chainId: 8453,
    },
    ...(address
      ? [
          {
            address: governorAddress as `0x${string}`,
            abi: GOVERNOR_ABI,
            functionName: 'hasVoted' as const,
            args: [BigInt(proposalId), address],
            chainId: 8453,
          },
        ]
      : []),
  ])

  // Add voting power contract
  const votingPowerContract =
    address && tokenAddress
      ? [
          {
            address: tokenAddress as `0x${string}`,
            abi: SUMMER_TOKEN_ABI,
            functionName: 'getVotes' as const,
            args: [address],
            chainId: 8453,
          },
        ]
      : []

  const contracts = [...proposalContracts, ...votingPowerContract]

  const { data: results, refetch } = useReadContracts({
    contracts,
    query: {
      enabled: proposalIds.length > 0 && !!governorAddress,
    },
  })

  // Parse results
  const proposalData: Record<string, { votes: ProposalVotes; hasVoted?: boolean }> = {}
  let votingPower: bigint = BigInt(0)

  if (results) {
    let resultIndex = 0

    for (const proposalId of proposalIds) {
      // Get proposal votes
      const votesResult = results[resultIndex]
      if (votesResult.status === 'success' && votesResult.result) {
        const [againstVotes, forVotes, abstainVotes] = votesResult.result as [
          bigint,
          bigint,
          bigint,
        ]
        proposalData[proposalId] = {
          votes: { againstVotes, forVotes, abstainVotes },
        }
      }
      resultIndex++

      // Get hasVoted if address exists
      if (address) {
        const hasVotedResult = results[resultIndex]
        if (hasVotedResult.status === 'success' && proposalData[proposalId]) {
          proposalData[proposalId].hasVoted = hasVotedResult.result as boolean
        }
        resultIndex++
      }
    }

    // Get voting power (last contract call)
    if (address && tokenAddress) {
      const votingPowerResult = results[results.length - 1]
      if (votingPowerResult.status === 'success') {
        votingPower = votingPowerResult.result as bigint
      }
    }
  }

  return {
    proposalData,
    votingPower,
    refetch,
    isLoading: !results,
  }
}
