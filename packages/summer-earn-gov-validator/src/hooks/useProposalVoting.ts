import {
  useConnection,
  useReadContract,
  useReadContracts,
  useSwitchChain,
  useWriteContract,
} from 'wagmi'

import config from '../config/index.json'

export const GOVERNOR_ABI = [
  {
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'calldatas', type: 'bytes[]' },
      { name: 'descriptionHash', type: 'bytes32' },
    ],
    name: 'execute',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'calldatas', type: 'bytes[]' },
      { name: 'descriptionHash', type: 'bytes32' },
    ],
    name: 'queue',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'proposalId', type: 'uint256' },
      { name: 'support', type: 'uint8' },
    ],
    name: 'castVote',
    outputs: [{ name: 'balance', type: 'uint256' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
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

const GOVERNOR_V2_ADDRESS = '0x4cEeE1b6289624d381383C1Bb42B118d5f2c3274'

const SUMMER_TOKEN_ABI = [
  {
    inputs: [{ name: 'account', type: 'address' }],
    name: 'getVotes',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'totalSupply',
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
  const { address } = useConnection()

  const governorAddress = config.base?.deployedContracts?.govV2?.summerGovernor?.address
  const tokenAddress = config.base?.deployedContracts?.govV2?.summerGovernanceToken?.address

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

  // Get total supply for quorum
  const { data: totalSupply } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: SUMMER_TOKEN_ABI,
    functionName: 'totalSupply',
    chainId: 8453, // Base chain
    query: {
      enabled: !!tokenAddress,
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
    totalSupply,
    refetch,
    // Only wait for userInfo if an address is connected
    isLoading: !votes || !totalSupply || (!!address && !userInfo),
  }
}

export function useMultipleProposalVoting(proposalIds: string[]) {
  const { address } = useConnection()

  const governorAddress = config.base?.deployedContracts?.govV2?.summerGovernor?.address
  const tokenAddress = config.base?.deployedContracts?.govV2?.summerGovernanceToken?.address

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

  const tokenContracts =
    address && tokenAddress
      ? [
          {
            address: tokenAddress as `0x${string}`,
            abi: SUMMER_TOKEN_ABI,
            functionName: 'getVotes' as const,
            args: [address],
            chainId: 8453,
          },
          {
            address: tokenAddress as `0x${string}`,
            abi: SUMMER_TOKEN_ABI,
            functionName: 'totalSupply' as const,
            args: [],
            chainId: 8453,
          },
        ]
      : tokenAddress
        ? [
            {
              address: tokenAddress as `0x${string}`,
              abi: SUMMER_TOKEN_ABI,
              functionName: 'totalSupply' as const,
              args: [],
              chainId: 8453,
            },
          ]
        : []

  const contracts = [...proposalContracts, ...tokenContracts]

  const { data: results, refetch } = useReadContracts({
    contracts,
    query: {
      enabled: proposalIds.length > 0 && !!governorAddress,
    },
  })

  // Parse results
  const proposalData: Record<string, { votes: ProposalVotes; hasVoted?: boolean }> = {}
  let votingPower: bigint = BigInt(0)
  let totalSupply: bigint = BigInt(1000000000) * BigInt(1e18) // Default fallback to 1B

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

    // Get token contract results
    if (tokenAddress) {
      if (address) {
        // [getVotes, totalSupply]
        const votingPowerResult = results[results.length - 2]
        const totalSupplyResult = results[results.length - 1]

        if (votingPowerResult.status === 'success') {
          votingPower = votingPowerResult.result as bigint
        }
        if (totalSupplyResult.status === 'success') {
          totalSupply = totalSupplyResult.result as bigint
        }
      } else {
        // [totalSupply]
        const totalSupplyResult = results[results.length - 1]
        if (totalSupplyResult.status === 'success') {
          totalSupply = totalSupplyResult.result as bigint
        }
      }
    }
  }

  return {
    proposalData,
    votingPower,
    totalSupply,
    refetch,
    isLoading: !results,
  }
}

export type VoteSupport = 0 | 1 | 2

export function useCastVote() {
  const { isConnected, chainId } = useConnection()

  const { mutate: switchChain } = useSwitchChain()

  const { mutate: writeContract, isPending: isVoting, isSuccess, error } = useWriteContract()

  const castVote = (proposalId: string, support: VoteSupport) => {
    if (!isConnected) {
      throw new Error('Wallet not connected')
    }
    if (chainId !== 8453) {
      switchChain({ chainId: 8453 })
    }
    writeContract({
      address: GOVERNOR_V2_ADDRESS,
      abi: GOVERNOR_ABI,
      functionName: 'castVote',
      args: [BigInt(proposalId), support],
      chainId: 8453,
    })
  }

  return {
    castVote,
    isVoting,
    isSuccess,
    error,
    isConnected,
  }
}
