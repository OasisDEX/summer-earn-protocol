import { Address } from 'viem'
import { arbitrum, base, mainnet, sonic } from 'viem/chains'
import { usePublicClient, useWalletClient } from 'wagmi'

import { RAFT_CONTRACT_ADDRESSES, REWARD_TOKENS } from '../config/environments'
import { useEnvironment } from '../hooks/useEnvironment'

export const RAFT_ABI = [
  {
    inputs: [
      { name: 'ark', type: 'address' },
      { name: 'rewardData', type: 'bytes' },
    ],
    name: 'harvest',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'ark', type: 'address' },
      { name: 'rewardData', type: 'bytes' },
    ],
    name: 'harvestAndStartAuction',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'ark', type: 'address' },
      { name: 'rewardToken', type: 'address' },
      {
        components: [
          { name: 'duration', type: 'uint40' },
          { name: 'startPrice', type: 'uint256' },
          { name: 'endPrice', type: 'uint256' },
          { name: 'kickerRewardPercentage', type: 'uint256' },
          { name: 'decayType', type: 'uint8' },
        ],
        name: 'parameters',
        type: 'tuple',
      },
    ],
    name: 'setArkAuctionParameters',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'ark', type: 'address' },
      { name: 'rewardToken', type: 'address' },
    ],
    name: 'obtainedTokens',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

export type BaseAuctionParameters = {
  duration: number
  startPrice: bigint
  endPrice: bigint
  kickerRewardPercentage: bigint
  decayType: number
}

export function useRaftContract() {
  const { environment } = useEnvironment()
  const publicClient = usePublicClient()
  const { data: walletClient } = useWalletClient()
  const getRaftAddress = (chainId: number) => {
    return RAFT_CONTRACT_ADDRESSES[environment][chainId] as Address
  }

  const getChain = (chainId: number) => {
    switch (chainId) {
      case mainnet.id:
        return mainnet
      case arbitrum.id:
        return arbitrum
      case base.id:
        return base
      case sonic.id:
        return sonic
      default:
        throw new Error(`Unsupported chain ID: ${chainId}`)
    }
  }

  const harvest = async (arkAddress: Address, chainId: number) => {
    if (!walletClient) throw new Error('No wallet client')
    if (!walletClient.account) throw new Error('No account')

    const raftAddress = getRaftAddress(chainId)
    return walletClient.writeContract({
      address: raftAddress,
      abi: RAFT_ABI,
      functionName: 'harvest',
      args: [arkAddress, '0x'],
      chain: getChain(chainId),
      account: walletClient.account,
    })
  }

  const harvestAndStartAuction = async (arkAddress: Address, chainId: number) => {
    if (!walletClient) throw new Error('No wallet client')
    if (!walletClient.account) throw new Error('No account')

    const raftAddress = getRaftAddress(chainId)
    return walletClient.writeContract({
      address: raftAddress,
      abi: RAFT_ABI,
      functionName: 'harvestAndStartAuction',
      args: [arkAddress, '0x'],
      chain: getChain(chainId),
      account: walletClient.account,
    })
  }

  const setAuctionParameters = async (
    arkAddress: Address,
    rewardToken: Address,
    parameters: BaseAuctionParameters,
    chainId: number,
  ) => {
    if (!walletClient) throw new Error('No wallet client')
    if (!walletClient.account) throw new Error('No account')

    const raftAddress = getRaftAddress(chainId)
    return walletClient.writeContract({
      address: raftAddress,
      abi: RAFT_ABI,
      functionName: 'setArkAuctionParameters',
      args: [arkAddress, rewardToken, parameters],
      chain: getChain(chainId),
      account: walletClient.account,
    })
  }

  const getObtainedTokens = async (arkAddress: Address, chainId: number) => {
    if (!publicClient) throw new Error('No public client')
    const raftAddress = getRaftAddress(chainId)
    const rewardTokens = REWARD_TOKENS[chainId] || []
    const results = await Promise.all(
      rewardTokens.map(async (tokenAddress) => {
        const amount = await // @ts-ignore
        publicClient.readContract({
          address: raftAddress,
          abi: RAFT_ABI,
          functionName: 'obtainedTokens',
          args: [arkAddress, tokenAddress as Address],
        })
        return {
          tokenAddress,
          amount,
        }
      }),
    )
    return results.filter((result) => result.amount > BigInt(0))
  }

  return {
    harvest,
    harvestAndStartAuction,
    setAuctionParameters,
    getObtainedTokens,
  }
}
