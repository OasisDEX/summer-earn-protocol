import { useCallback, useEffect, useMemo, useState } from 'react'
import { toast } from 'sonner'
import { erc20Abi } from 'viem'
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useWaitForTransactionReceipt,
  useWriteContract,
} from 'wagmi'

import {
  STAKED_SUMMER_TOKEN_ADDRESSES,
  SUMMER_STAKING_ADDRESSES,
  SUMMER_TOKEN_ADDRESSES,
} from '../config/environments'
import type { ChainId } from '../types'
import { useEnvironment } from './useEnvironment'
// Local ABI (inline to avoid import issues)
const summerStakingAbi = [
  {
    type: 'function',
    name: 'stakeLockup',
    stateMutability: 'nonpayable',
    inputs: [
      { name: '_amount', type: 'uint256' },
      { name: '_lockupPeriod', type: 'uint256' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'unstakeLockup',
    stateMutability: 'nonpayable',
    inputs: [
      { name: '_stakeIndex', type: 'uint256' },
      { name: '_amount', type: 'uint256' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'getAllBucketInfo',
    stateMutability: 'view',
    inputs: [],
    outputs: [
      { name: 'buckets', type: 'uint8[]' },
      { name: 'caps', type: 'uint256[]' },
      { name: 'stakedAmounts', type: 'uint256[]' },
      { name: 'minPeriods', type: 'uint256[]' },
      { name: 'maxPeriods', type: 'uint256[]' },
    ],
  },
  {
    type: 'function',
    name: 'getUserStakesCount',
    stateMutability: 'view',
    inputs: [{ name: '_user', type: 'address' }],
    outputs: [{ name: 'count', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'getUserStake',
    stateMutability: 'view',
    inputs: [
      { name: '_user', type: 'address' },
      { name: '_index', type: 'uint256' },
    ],
    outputs: [
      { name: 'amount', type: 'uint256' },
      { name: 'weightedAmount', type: 'uint256' },
      { name: 'lockupEndTime', type: 'uint256' },
      { name: 'lockupPeriod', type: 'uint256' },
    ],
  },
  {
    type: 'function',
    name: 'calculatePenalty',
    stateMutability: 'view',
    inputs: [
      { name: '_user', type: 'address' },
      { name: '_amount', type: 'uint256' },
      { name: '_stakeIndex', type: 'uint256' },
    ],
    outputs: [{ name: 'penalty', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'calculatePenaltyPercentage',
    stateMutability: 'view',
    inputs: [
      { name: '_user', type: 'address' },
      { name: '_stakeIndex', type: 'uint256' },
    ],
    outputs: [{ name: 'penaltyPct', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'calculateWeightedStake',
    stateMutability: 'pure',
    inputs: [
      { name: '_amount', type: 'uint256' },
      { name: '_lockupPeriod', type: 'uint256' },
    ],
    outputs: [{ name: 'weighted', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'weightedBalanceOf',
    stateMutability: 'view',
    inputs: [{ name: 'address', type: 'address' }],
    outputs: [{ name: 'weighted', type: 'uint256' }],
  },
] as const

export interface UserStakeView {
  index: number
  amount: bigint
  weightedAmount: bigint
  lockupEndTime: bigint
  lockupPeriod: bigint
  multiplierWad: bigint // weighted/amount in 1e18
}

const WAD = BigInt('1000000000000000000')
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

const isNonZeroAddress = (addr: string | undefined): addr is `0x${string}` =>
  Boolean(addr && addr !== ZERO_ADDRESS)

export function useSummerStaking(chainId: ChainId) {
  const { environment } = useEnvironment()
  const { address: account, chain } = useAccount()
  // Resolve and sanitize chain id from route param; fall back to Base (8453) if invalid or unmapped
  const rawChainId = Number(chainId)
  const hasMappingFor = (cid: number) => {
    const summer = SUMMER_TOKEN_ADDRESSES[environment]?.[cid]
    const xSummer = STAKED_SUMMER_TOKEN_ADDRESSES[environment]?.[cid]
    const staking = SUMMER_STAKING_ADDRESSES[environment]?.[cid]
    return Boolean(
      isNonZeroAddress(summer) && isNonZeroAddress(xSummer) && isNonZeroAddress(staking),
    )
  }
  const chainIdNumber = Number.isFinite(rawChainId) && hasMappingFor(rawChainId) ? rawChainId : 8453
  // Initialize public client for the resolved chain id; also keep a default client as fallback
  const pcForChain = usePublicClient({ chainId: chainIdNumber })
  const publicClient = pcForChain

  // Memoize addresses to ensure they update when environment or chainId changes
  const { summerAddress, xSummerAddress, stakingAddress } = useMemo(() => {
    const summer = SUMMER_TOKEN_ADDRESSES[environment]?.[chainIdNumber]
    const xSummer = STAKED_SUMMER_TOKEN_ADDRESSES[environment]?.[chainIdNumber]
    const staking = SUMMER_STAKING_ADDRESSES[environment]?.[chainIdNumber]
    return {
      summerAddress: isNonZeroAddress(summer) ? summer : undefined,
      xSummerAddress: isNonZeroAddress(xSummer) ? xSummer : undefined,
      stakingAddress: isNonZeroAddress(staking) ? staking : undefined,
    }
  }, [environment, chainIdNumber])
  // Reads
  const { data: bucketInfo } = useReadContract({
    abi: summerStakingAbi,
    address: stakingAddress!,
    functionName: 'getAllBucketInfo',
    query: { enabled: Boolean(isNonZeroAddress(stakingAddress)) },
  })

  const { data: userStakeCount } = useReadContract({
    abi: summerStakingAbi,
    address: stakingAddress!,
    functionName: 'getUserStakesCount',
    args: account ? [account] : undefined,
    query: { enabled: Boolean(isNonZeroAddress(stakingAddress) && account) },
    chainId: chainIdNumber,
  })

  // ERC20 metadata
  const { data: summerDecimals } = useReadContract({
    abi: erc20Abi,
    address: summerAddress!,
    functionName: 'decimals',
    query: { enabled: Boolean(isNonZeroAddress(summerAddress)) },
    chainId: chainIdNumber,
  })
  const { data: summerSymbol } = useReadContract({
    abi: erc20Abi,
    address: summerAddress!,
    functionName: 'symbol',
    query: { enabled: Boolean(isNonZeroAddress(summerAddress)) },
    chainId: chainIdNumber,
  })

  // Balances
  const { data: summerBalance } = useReadContract({
    abi: erc20Abi,
    address: summerAddress!,
    functionName: 'balanceOf',
    args: account ? [account] : undefined,
    query: { enabled: Boolean(isNonZeroAddress(summerAddress) && account) },
    chainId: chainIdNumber,
  })

  const { data: xSummerBalance } = useReadContract({
    abi: erc20Abi,
    address: xSummerAddress!,
    functionName: 'balanceOf',
    args: account ? [account] : undefined,
    query: { enabled: Boolean(isNonZeroAddress(xSummerAddress) && account) },
    chainId: chainIdNumber,
  })

  // Allowances
  const { data: summerAllowance, refetch: refetchSummerAllowance } = useReadContract({
    abi: erc20Abi,
    address: summerAddress!,
    functionName: 'allowance',
    args: account && stakingAddress ? [account, stakingAddress] : undefined,
    query: {
      enabled: Boolean(
        account && isNonZeroAddress(summerAddress) && isNonZeroAddress(stakingAddress),
      ),
    },
    chainId: chainIdNumber,
  })
  const { data: xSummerAllowance, refetch: refetchXSummerAllowance } = useReadContract({
    abi: erc20Abi,
    address: xSummerAddress!,
    functionName: 'allowance',
    args: account && stakingAddress ? [account, stakingAddress] : undefined,
    query: {
      enabled: Boolean(
        account && isNonZeroAddress(xSummerAddress) && isNonZeroAddress(stakingAddress),
      ),
    },
    chainId: chainIdNumber,
  })

  // Load stakes list via multicall
  const [stakes, setStakes] = useState<UserStakeView[]>([])
  useEffect(() => {
    let cancelled = false
    async function load() {
      if (!publicClient || !account || !isNonZeroAddress(stakingAddress)) {
        if (!cancelled) setStakes([])
        return
      }
      const count = Number((userStakeCount as bigint) || BigInt(0))
      if (count === 0) {
        if (!cancelled) setStakes([])
        return
      }
      const calls = Array.from({ length: count }, (_, i) => ({
        address: stakingAddress,
        abi: summerStakingAbi,
        functionName: 'getUserStake' as const,
        args: [account as `0x${string}`, BigInt(i)],
      }))
      try {
        // @ts-expect-error - wagmi types are not up to date
        const res = await publicClient.multicall({ contracts: calls, allowFailure: true })
        const items: UserStakeView[] = []
        for (let i = 0; i < res.length; i++) {
          const r = res[i]
          if (r.status === 'success') {
            const [amount, weightedAmount, lockupEndTime, lockupPeriod] = r.result as unknown as [
              bigint,
              bigint,
              bigint,
              bigint,
            ]
            const multiplierWad = amount > BigInt(0) ? (weightedAmount * WAD) / amount : BigInt(0)
            console.log(weightedAmount)
            items.push({
              index: i,
              amount,
              weightedAmount,
              lockupEndTime,
              lockupPeriod,
              multiplierWad,
            })
          }
        }
        if (!cancelled) setStakes(items)
      } catch (error) {
        console.error('Failed to load stake data', error)
        if (!cancelled) setStakes([])
      }
    }
    load()
    return () => {
      cancelled = true
    }
  }, [publicClient, account, stakingAddress, userStakeCount, environment])

  // Actions
  const { writeContract: write, data: txHash, isPending } = useWriteContract()
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash: txHash,
  })

  useEffect(() => {
    if (!txHash) return
    // success notifications handled by consumers; here keep minimal
    if (isConfirmed) {
      toast.success('Transaction confirmed')
      refetchSummerAllowance?.()
      refetchXSummerAllowance?.()
    }
  }, [txHash, isConfirmed, refetchSummerAllowance, refetchXSummerAllowance])

  const approveSummer = useCallback(() => {
    if (!summerAddress || !stakingAddress) return
    try {
      toast.loading('Approving SUMMER…', { id: 'approve-summer' })
      write({
        abi: erc20Abi,
        address: summerAddress,
        account: account,
        functionName: 'approve',
        args: [
          stakingAddress,
          BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'),
        ] as const,
        chain,
      } as Parameters<typeof write>[0])
    } catch (e) {
      console.error('approveSummer error', e)
      toast.error('Approve failed', { id: 'approve-summer' })
    }
  }, [write, summerAddress, stakingAddress, account, chain])

  const approveXSummer = useCallback(() => {
    if (!xSummerAddress || !stakingAddress) return
    try {
      toast.loading('Approving xSUMR…', { id: 'approve-xsummer' })
      write({
        abi: erc20Abi,
        address: xSummerAddress,
        account: account,
        functionName: 'approve',
        args: [
          stakingAddress,
          BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'),
        ] as const,
        chain,
      } as Parameters<typeof write>[0])
    } catch (e) {
      console.error('approveXSummer error', e)
      toast.error('Approve failed', { id: 'approve-xsummer' })
    }
  }, [write, xSummerAddress, stakingAddress, account, chain])

  const stakeLockup = useCallback(
    (amount: bigint, lockup: bigint) => {
      if (!stakingAddress || amount <= BigInt(0)) return
      try {
        toast.loading('Staking…', { id: 'stake' })
        write({
          abi: summerStakingAbi,
          address: stakingAddress,
          account: account,
          functionName: 'stakeLockup',
          args: [amount, lockup] as const,
          chain,
        } as Parameters<typeof write>[0])
      } catch (e) {
        console.error('stakeLockup error', e)
        toast.error('Stake failed', { id: 'stake' })
      }
    },
    [write, stakingAddress, account, chain],
  )

  const unstakeLockup = useCallback(
    (index: number, amount: bigint) => {
      if (!stakingAddress || amount <= BigInt(0)) return
      try {
        toast.loading('Unstaking…', { id: 'unstake' })
        write({
          abi: summerStakingAbi,
          address: stakingAddress,
          account: account,
          functionName: 'unstakeLockup',
          args: [BigInt(index), amount] as const,
          chain,
        } as Parameters<typeof write>[0])
      } catch (e) {
        console.error('unstakeLockup error', e)
        toast.error('Unstake failed', { id: 'unstake' })
      }
    },
    [write, stakingAddress, account, chain],
  )

  // Helpers
  const needsSummerApproval = useCallback(
    (amount: bigint) => {
      const a = (summerAllowance as bigint) || BigInt(0)
      return a < amount
    },
    [summerAllowance],
  )
  const needsXSummerApproval = useCallback(
    (amount: bigint) => {
      const a = (xSummerAllowance as bigint) || BigInt(0)
      return a < amount
    },
    [xSummerAllowance],
  )

  const totalUserAmount = useMemo(() => stakes.reduce((s, x) => s + x.amount, BigInt(0)), [stakes])
  const totalUserWeighted = useMemo(
    () => stakes.reduce((s, x) => s + x.weightedAmount, BigInt(0)),
    [stakes],
  )
  const currentOverallMultiplierWad = useMemo(
    () => (totalUserAmount > BigInt(0) ? (totalUserWeighted * WAD) / totalUserAmount : WAD),
    [totalUserAmount, totalUserWeighted],
  )

  // Bucket view model
  const buckets = useMemo(() => {
    if (!bucketInfo)
      return [] as {
        key: number
        cap: bigint
        staked: bigint
        min: bigint
        max: bigint
        remainingPct: number
        color: string
      }[]
    const [bucketIds, caps, staked, minPeriods, maxPeriods] = bucketInfo as unknown as [
      number[],
      bigint[],
      bigint[],
      bigint[],
      bigint[],
    ]
    const items = bucketIds.map((b, i) => {
      const cap = caps[i]
      const st = staked[i]
      const remaining =
        cap > BigInt(0) ? (cap > st ? Number(((cap - st) * BigInt(10000)) / cap) / 100 : 0) : 0
      let color = 'bg-green-600'
      // Assumption: thresholds are remaining capacity. <=25% red; <=50% orange; <=75% yellow; else green
      if (cap === BigInt(0)) {
        color = 'bg-gray-600'
      } else if (remaining <= 25) {
        color = 'bg-red-600'
      } else if (remaining <= 50) {
        color = 'bg-orange-500'
      } else if (remaining <= 75) {
        color = 'bg-yellow-500'
      } else {
        color = 'bg-green-600'
      }
      return {
        key: b,
        cap,
        staked: st,
        min: minPeriods[i],
        max: maxPeriods[i],
        remainingPct: remaining,
        color,
      }
    })
    return items
  }, [bucketInfo])

  return {
    // addresses
    summerAddress,
    xSummerAddress,
    stakingAddress,

    // metadata
    summerDecimals: (summerDecimals as number) ?? 18,
    summerSymbol: (summerSymbol as string) ?? 'SUMMER',

    // data
    buckets,
    stakes,
    userStakeCount: Number((userStakeCount as bigint) || BigInt(0)),
    currentOverallMultiplierWad,

    // balances
    summerBalance: (summerBalance as bigint) || BigInt(0),
    xSummerBalance: (xSummerBalance as bigint) || BigInt(0),

    // allowances
    summerAllowance: (summerAllowance as bigint) || BigInt(0),
    xSummerAllowance: (xSummerAllowance as bigint) || BigInt(0),
    refetchSummerAllowance,
    refetchXSummerAllowance,

    // actions
    approveSummer,
    approveXSummer,
    stakeLockup,
    unstakeLockup,

    // helpers
    needsSummerApproval,
    needsXSummerApproval,

    // tx state
    txHash,
    isPending,
    isConfirming,
    isConfirmed,
  }
}
