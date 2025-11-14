import { useCallback, useEffect, useMemo } from 'react'
import { toast } from 'sonner'
import { erc20Abi, zeroAddress } from 'viem'
import { useAccount, useReadContract, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

import {
  STAKED_SUMMER_TOKEN_ADDRESSES,
  SUMMER_TOKEN_ADDRESSES,
  SUMMER_VESTING_WALLET_FACTORY_V2_ADDRESSES,
  SUMMER_VESTING_WALLETS_ESCROW_ADDRESSES,
} from '../config/environments'
import type { ChainId } from '../types'
import { useEnvironment } from './useEnvironment'

// Escrow ABI
const escrowAbi = [
  {
    type: 'function',
    name: 'stakeVesting',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'factories', type: 'address[]' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'unstakeVesting',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'factories', type: 'address[]' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'addVestingFactory',
    stateMutability: 'nonpayable',
    inputs: [{ name: '_vestingFactory', type: 'address' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'removeVestingFactory',
    stateMutability: 'nonpayable',
    inputs: [{ name: '_vestingFactory', type: 'address' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'vestingFactories',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: 'factories', type: 'address[]' }],
  },
  {
    type: 'function',
    name: 'userStakedVestingFactories',
    stateMutability: 'view',
    inputs: [{ name: 'user', type: 'address' }],
    outputs: [{ name: 'factories', type: 'address[]' }],
  },
] as const

// Factory V2 ABI
const factoryV2Abi = [
  {
    type: 'function',
    name: 'createVestingWallet',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'beneficiary', type: 'address' },
      {
        name: 'vestingParams',
        type: 'tuple',
        components: [
          { name: 'cliffEndTimestamp', type: 'uint64' },
          { name: 'cliffAmount', type: 'uint256' },
          { name: 'vestingPeriods', type: 'uint256' },
          { name: 'totalVestingAmount', type: 'uint256' },
        ],
      },
      {
        name: 'performanceGoals',
        type: 'tuple[]',
        components: [
          { name: 'amount', type: 'uint256' },
          { name: 'description', type: 'string' },
          { name: 'reached', type: 'bool' },
        ],
      },
    ],
    outputs: [{ name: 'newVestingWallet', type: 'address' }],
  },
  {
    type: 'function',
    name: 'vestingWallets',
    stateMutability: 'view',
    inputs: [{ name: 'beneficiary', type: 'address' }],
    outputs: [{ name: '', type: 'address' }],
  },
  {
    type: 'function',
    name: 'token',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
] as const

// Minimal Vesting Wallet ABI
const vestingWalletAbi = [
  {
    type: 'function',
    name: 'owner',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
  {
    type: 'function',
    name: 'transferOwnership',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'newOwner', type: 'address' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'released',
    stateMutability: 'view',
    inputs: [{ name: '_token', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
] as const

export interface VestingParams {
  cliffEndTimestamp: number
  cliffAmount: bigint
  vestingPeriods: bigint
  totalVestingAmount: bigint
}

export interface PerformanceGoal {
  amount: bigint
  description: string
  reached: boolean
}

export function useVestingWallets(chainId: ChainId) {
  const { environment } = useEnvironment()
  const { address: account, chain } = useAccount()
  const rawChainId = Number(chainId)
  const chainIdNumber = Number.isFinite(rawChainId) ? rawChainId : 8453

  const escrowAddress = SUMMER_VESTING_WALLETS_ESCROW_ADDRESSES[environment]?.[chainIdNumber] as
    | `0x${string}`
    | undefined
  const factoryV2Address = SUMMER_VESTING_WALLET_FACTORY_V2_ADDRESSES[environment]?.[
    chainIdNumber
  ] as `0x${string}` | undefined
  const summerTokenAddress = SUMMER_TOKEN_ADDRESSES[environment]?.[chainIdNumber] as
    | `0x${string}`
    | undefined
  const xSummerTokenAddress = STAKED_SUMMER_TOKEN_ADDRESSES[environment]?.[chainIdNumber] as
    | `0x${string}`
    | undefined

  // Read operations
  const { data: enabledFactories, refetch: refetchFactories } = useReadContract({
    abi: escrowAbi,
    address: escrowAddress,
    functionName: 'vestingFactories',
    query: {
      enabled: Boolean(escrowAddress),
    },
  })

  const { data: userStakedFactories, refetch: refetchUserStakedFactories } = useReadContract({
    abi: escrowAbi,
    address: escrowAddress,
    functionName: 'userStakedVestingFactories',
    args: account ? [account] : undefined,
    query: {
      enabled: Boolean(escrowAddress && account),
    },
  })

  const { data: userVestingWallet } = useReadContract({
    abi: factoryV2Abi,
    address: factoryV2Address,
    functionName: 'vestingWallets',
    args: account ? [account] : undefined,
    query: {
      enabled: Boolean(factoryV2Address && account),
    },
  })

  const { data: vestingWalletOwner } = useReadContract({
    abi: vestingWalletAbi,
    address: userVestingWallet as `0x${string}` | undefined,
    functionName: 'owner',
    query: { enabled: Boolean(userVestingWallet) },
  })

  const { data: vestingWalletReleased } = useReadContract({
    abi: vestingWalletAbi,
    address: userVestingWallet as `0x${string}` | undefined,
    functionName: 'released',
    args: userVestingWallet && summerTokenAddress ? [summerTokenAddress] : undefined,
    query: { enabled: Boolean(userVestingWallet && summerTokenAddress) },
  })

  const { data: vestingWalletBalance } = useReadContract({
    abi: erc20Abi,
    address: summerTokenAddress,
    functionName: 'balanceOf',
    args: userVestingWallet ? [userVestingWallet as `0x${string}`] : undefined,
    query: { enabled: Boolean(summerTokenAddress && userVestingWallet) },
  })

  const { data: summerBalance } = useReadContract({
    abi: erc20Abi,
    address: summerTokenAddress,
    functionName: 'balanceOf',
    args: account ? [account] : undefined,
    query: { enabled: Boolean(summerTokenAddress && account) },
  })

  const { data: summerAllowance } = useReadContract({
    abi: erc20Abi,
    address: summerTokenAddress,
    functionName: 'allowance',
    args: account && factoryV2Address ? [account, factoryV2Address] : undefined,
    query: { enabled: Boolean(summerTokenAddress && account && factoryV2Address) },
  })

  const { data: xSummerAllowance, refetch: refetchXSummerAllowance } = useReadContract({
    abi: erc20Abi,
    address: xSummerTokenAddress,
    functionName: 'allowance',
    args: account && escrowAddress ? [account, escrowAddress] : undefined,
    query: { enabled: Boolean(xSummerTokenAddress && account && escrowAddress) },
  })

  // Write operations
  const { writeContract, data: txHash, isPending, isError } = useWriteContract()
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash: txHash,
  })

  // Create vesting wallet
  const createVestingWallet = useCallback(
    async (
      beneficiary: `0x${string}`,
      vestingParams: VestingParams,
      performanceGoals: PerformanceGoal[] = [],
    ) => {
      if (!factoryV2Address) {
        toast.error('Factory V2 address not configured for this chain')
        return
      }

      try {
        await writeContract({
          address: factoryV2Address,
          abi: factoryV2Abi,
          functionName: 'createVestingWallet',
          args: [
            beneficiary,
            {
              cliffEndTimestamp: BigInt(vestingParams.cliffEndTimestamp),
              cliffAmount: vestingParams.cliffAmount,
              vestingPeriods: vestingParams.vestingPeriods,
              totalVestingAmount: vestingParams.totalVestingAmount,
            },
            performanceGoals.map((g) => ({
              amount: g.amount,
              description: g.description,
              reached: g.reached,
            })),
          ],
          account,
          chain,
        } as Parameters<typeof writeContract>[0])
      } catch (error: any) {
        toast.error(error?.message || 'Failed to create vesting wallet')
        throw error
      }
    },
    [factoryV2Address, writeContract, account, chain],
  )

  // Approve factory to spend tokens
  const approveFactory = useCallback(async () => {
    if (!factoryV2Address || !summerTokenAddress) {
      toast.error('Addresses not configured')
      return
    }

    try {
      await writeContract({
        address: summerTokenAddress,
        abi: erc20Abi,
        functionName: 'approve',
        args: [
          factoryV2Address,
          BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'),
        ],
        account,
        chain,
      } as Parameters<typeof writeContract>[0])
    } catch (error: any) {
      toast.error(error?.message || 'Failed to approve')
      throw error
    }
  }, [factoryV2Address, summerTokenAddress, writeContract, account, chain])

  // Approve escrow to burn xSUMR tokens (required for unstaking)
  const approveEscrow = useCallback(async () => {
    if (!escrowAddress || !xSummerTokenAddress) {
      toast.error('Addresses not configured')
      return
    }

    try {
      await writeContract({
        address: xSummerTokenAddress,
        abi: erc20Abi,
        functionName: 'approve',
        args: [
          escrowAddress,
          BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'),
        ],
        account,
        chain,
      } as Parameters<typeof writeContract>[0])
    } catch (error: any) {
      toast.error(error?.message || 'Failed to approve xSUMR')
      throw error
    }
  }, [escrowAddress, xSummerTokenAddress, writeContract, account, chain])

  // Transfer vesting wallet ownership to escrow (required before staking)
  const transferOwnershipToEscrow = useCallback(async () => {
    if (!userVestingWallet || !escrowAddress) {
      toast.error('Vesting wallet or escrow address not found')
      return
    }

    try {
      await writeContract({
        address: userVestingWallet as `0x${string}`,
        abi: vestingWalletAbi,
        functionName: 'transferOwnership',
        args: [escrowAddress],
        account,
        chain,
      } as Parameters<typeof writeContract>[0])
    } catch (error: any) {
      toast.error(error?.message || 'Failed to transfer ownership')
      throw error
    }
  }, [userVestingWallet, escrowAddress, writeContract, account, chain])

  // Stake vesting wallet
  const stakeVesting = useCallback(
    async (factories: `0x${string}`[]) => {
      if (!escrowAddress) {
        toast.error('Escrow address not configured')
        return
      }

      try {
        await writeContract({
          address: escrowAddress,
          abi: escrowAbi,
          functionName: 'stakeVesting',
          args: [factories],
          account,
          chain,
        } as Parameters<typeof writeContract>[0])
      } catch (error: any) {
        toast.error(error?.message || 'Failed to stake vesting wallet')
        throw error
      }
    },
    [escrowAddress, writeContract, account, chain],
  )

  // Unstake vesting wallet
  const unstakeVesting = useCallback(
    async (factories: `0x${string}`[]) => {
      if (!escrowAddress) {
        toast.error('Escrow address not configured')
        return
      }

      try {
        await writeContract({
          address: escrowAddress,
          abi: escrowAbi,
          functionName: 'unstakeVesting',
          args: [factories],
          account,
          chain,
        } as Parameters<typeof writeContract>[0])
      } catch (error: any) {
        toast.error(error?.message || 'Failed to unstake vesting wallet')
        throw error
      }
    },
    [escrowAddress, writeContract, account, chain],
  )

  // Add factory to escrow (admin only)
  const addFactory = useCallback(
    async (factory: `0x${string}`) => {
      if (!escrowAddress) {
        toast.error('Escrow address not configured')
        return
      }

      try {
        await writeContract({
          address: escrowAddress,
          abi: escrowAbi,
          functionName: 'addVestingFactory',
          args: [factory],
          account,
          chain,
        } as Parameters<typeof writeContract>[0])
      } catch (error: any) {
        toast.error(error?.message || 'Failed to add factory')
        throw error
      }
    },
    [escrowAddress, writeContract, account, chain],
  )

  // Check if user needs approval
  const needsFactoryApproval = useCallback(
    (amount: bigint) => {
      if (!amount || amount === 0n) return false
      if (!summerAllowance) return true // If allowance is undefined, we need approval
      return summerAllowance < amount
    },
    [summerAllowance],
  )

  // Check if user needs approval for escrow to burn xSUMR
  const needsEscrowApproval = useCallback(
    (amount: bigint) => {
      if (!amount || amount === 0n) return false
      if (!xSummerAllowance) return true // If allowance is undefined, we need approval
      return xSummerAllowance < amount
    },
    [xSummerAllowance],
  )

  // Check if wallet is owned by escrow
  const isOwnedByEscrow = useMemo(() => {
    if (!escrowAddress || !vestingWalletOwner) return false
    return vestingWalletOwner.toLowerCase() === escrowAddress.toLowerCase()
  }, [escrowAddress, vestingWalletOwner])

  // Check if factory is staked
  const isFactoryStaked = useMemo(() => {
    if (!factoryV2Address || !userStakedFactories) return false
    return (userStakedFactories as `0x${string}`[]).some(
      (f) => f.toLowerCase() === factoryV2Address.toLowerCase(),
    )
  }, [factoryV2Address, userStakedFactories])

  // Refetch after transaction
  useEffect(() => {
    if (isConfirmed) {
      refetchFactories()
      refetchUserStakedFactories()
      refetchXSummerAllowance?.()
      toast.success('Transaction confirmed')
    }
  }, [isConfirmed, refetchFactories, refetchUserStakedFactories, refetchXSummerAllowance])

  return {
    // Addresses
    escrowAddress,
    factoryV2Address,
    summerTokenAddress,
    userVestingWallet:
      userVestingWallet == zeroAddress || userVestingWallet == undefined
        ? undefined
        : (userVestingWallet as `0x${string}`),

    // Data
    enabledFactories: (enabledFactories as `0x${string}`[] | undefined) || [],
    userStakedFactories: (userStakedFactories as `0x${string}`[] | undefined) || [],
    vestingWalletOwner: vestingWalletOwner as `0x${string}` | undefined,
    vestingWalletReleased: (vestingWalletReleased as bigint) || 0n,
    vestingWalletBalance: (vestingWalletBalance as bigint) || 0n,
    summerBalance: (summerBalance as bigint) || 0n,
    summerAllowance: (summerAllowance as bigint) || 0n,
    xSummerAllowance: (xSummerAllowance as bigint) || 0n,
    refetchXSummerAllowance,

    // State
    isOwnedByEscrow,
    isFactoryStaked,
    needsFactoryApproval,
    needsEscrowApproval,

    // Actions
    createVestingWallet,
    approveFactory,
    approveEscrow,
    transferOwnershipToEscrow,
    stakeVesting,
    unstakeVesting,
    addFactory,

    // Transaction state
    txHash,
    isPending,
    isConfirming,
    isConfirmed,
    isError,
  }
}
