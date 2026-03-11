'use client'

import { Suspense, useEffect, useMemo, useState } from 'react'
import Link from 'next/link'
import { useParams, useRouter, useSearchParams } from 'next/navigation'
import { getAddress, isAddress } from 'viem'
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useWaitForTransactionReceipt,
  useWriteContract,
} from 'wagmi'
import { base as baseChain } from 'wagmi/chains'

import { VIEM_CHAIN_ENTITIES } from '@/config/chains'

import { erc20Abi } from '../../../abis/ERC20'
import { summerVestingWalletAbi } from '../../../abis/SummerVestingWallet'
import { summerVestingWalletEscrowAbi } from '../../../abis/SummerVestingWalletEscrow'
import { summerVestingWalletFactoryAbi } from '../../../abis/SummerVestingWalletFactory'
import { summerVestingWalletFactoryV2Abi } from '../../../abis/SummerVestingWalletFactoryV2'
import { summerVestingWalletV2Abi } from '../../../abis/SummerVestingWalletV2'
import { ChainPills } from '../../../components/ChainPills'
import { ConnectButton } from '../../../components/ConnectButton'
import { GlassCard } from '../../../components/GlassCard'
import { ProgressBar } from '../../../components/ProgressBar'
import { StatCard } from '../../../components/StatCard'
import {
  SUMMER_VESTING_WALLET_FACTORY_ADDRESSES,
  SUMMER_VESTING_WALLET_FACTORY_V2_ADDRESSES,
  SUMMER_VESTING_WALLETS_ESCROW_ADDRESSES,
} from '../../../config/environments'
import { useEnvironment } from '../../../hooks/useEnvironment'
import { useSyncWalletChain } from '../../../hooks/useSyncWalletChain'
import type { ChainId } from '../../../types'
import { formatDecimalOutput } from '../../../utils/decimals'

const ADDRESS_ZERO = '0x0000000000000000000000000000000000000000'

type V2GoalResult = {
  amount: bigint
  reached: boolean
  description?: string
}

const toBigIntOrNull = (value: unknown): bigint | null => {
  if (typeof value === 'bigint') return value
  if (typeof value === 'number') return BigInt(value)
  if (typeof value === 'string' && value.trim() !== '') {
    try {
      return BigInt(value)
    } catch {
      return null
    }
  }
  return null
}

const extractVestingParam = (value: unknown, index: number, key?: string): bigint | null => {
  if (value === null || value === undefined) return null
  if (Array.isArray(value)) {
    return toBigIntOrNull(value[index])
  }
  if (typeof value === 'object') {
    const record = value as Record<string, unknown>
    if (key && record[key] !== undefined) {
      const keyed = toBigIntOrNull(record[key])
      if (keyed !== null) return keyed
    }
    if (record[index] !== undefined) {
      const indexed = toBigIntOrNull(record[index])
      if (indexed !== null) return indexed
    }
    if (record[String(index)] !== undefined) {
      const named = toBigIntOrNull(record[String(index)])
      if (named !== null) return named
    }
  }
  return null
}

const parseV2GoalResult = (value: unknown): V2GoalResult | null => {
  if (value === null || value === undefined) return null
  if (Array.isArray(value)) {
    const [amountValue, reachedValue, descriptionValue] = value as [unknown, unknown, unknown]
    const amount = toBigIntOrNull(amountValue)
    if (amount === null) return null
    const reached = typeof reachedValue === 'boolean' ? reachedValue : Boolean(reachedValue)
    const description =
      typeof descriptionValue === 'string' && descriptionValue.length > 0
        ? descriptionValue
        : undefined
    return { amount, reached, description }
  }
  if (typeof value === 'object') {
    const record = value as Record<string, unknown>
    const amount =
      toBigIntOrNull(record.amount) ??
      toBigIntOrNull(record[0]) ??
      toBigIntOrNull(record['0']) ??
      null
    if (amount === null) return null
    const reachedRaw = record.reached ?? record[1] ?? record['1']
    const reached = typeof reachedRaw === 'boolean' ? reachedRaw : Boolean(reachedRaw)
    const descriptionRaw = record.description ?? record[2] ?? record['2']
    const description =
      typeof descriptionRaw === 'string' && descriptionRaw.length > 0 ? descriptionRaw : undefined
    return { amount, reached, description }
  }
  return null
}

type MulticallResult<T> =
  | {
      status: 'success'
      result: T
    }
  | {
      status: 'failure'
      result?: undefined
    }

const VALID_CHAINS: ChainId[] = ['1', '42161', '8453', '146']

function VestingContent() {
  const params = useParams()
  const router = useRouter()
  const searchParams = useSearchParams()
  const chainId = params.chainId as ChainId
  const { address, isConnected } = useAccount()
  const { environment } = useEnvironment()

  useSyncWalletChain(chainId)

  const factoryAddress = SUMMER_VESTING_WALLET_FACTORY_ADDRESSES[environment][Number(chainId)]
  const factoryV2Address = SUMMER_VESTING_WALLET_FACTORY_V2_ADDRESSES[environment][Number(chainId)]

  const isBase = Number(chainId) === baseChain.id

  // Manual address override for fetching (takes precedence over connected address)
  const [inputAddress, setInputAddress] = useState('')
  const [lookupAddress, setLookupAddress] = useState<`0x${string}` | null>(null)
  const [addressError, setAddressError] = useState<string | null>(null)

  const queryAddress = (lookupAddress ?? address) as `0x${string}` | undefined

  const onFetchAddress = () => {
    const candidate = inputAddress.trim()
    if (!candidate) {
      setLookupAddress(null)
      setAddressError(null)
      return
    }
    if (isAddress(candidate)) {
      setLookupAddress(getAddress(candidate) as `0x${string}`)
      setAddressError(null)
    } else {
      setAddressError('Invalid address')
    }
  }

  const onClearOverride = () => {
    setLookupAddress(null)
    setInputAddress('')
    setAddressError(null)
  }

  // Deep link from batch table: ?address=0x...
  useEffect(() => {
    const addr = searchParams.get('address')
    if (addr && isAddress(addr)) {
      setInputAddress(addr)
      setLookupAddress(getAddress(addr) as `0x${string}`)
      setAddressError(null)
    }
  }, [searchParams])

  const handleChainChange = (newChainId: ChainId) => {
    router.push(`/vesting/${newChainId}${lookupAddress ? `?address=${lookupAddress}` : ''}`)
  }

  // Lookup vesting wallet for target user in V1 factory first
  const { data: vestingWalletAddressV1 } = useReadContract({
    abi: summerVestingWalletFactoryAbi,
    address: factoryAddress as `0x${string}`,
    functionName: 'vestingWallets',
    args: queryAddress ? [queryAddress] : undefined,
    query: { enabled: !!queryAddress && !!factoryAddress },
  })

  // Lookup vesting wallet for target user in V2 factory if V1 not found
  const { data: vestingWalletAddressV2 } = useReadContract({
    abi: summerVestingWalletFactoryV2Abi,
    address: factoryV2Address as `0x${string}`,
    functionName: 'vestingWallets',
    args: queryAddress ? [queryAddress] : undefined,
    query: { enabled: !!queryAddress && !!factoryV2Address && !vestingWalletAddressV1 },
  })
  // Use V1 if found, otherwise V2
  const isV1Valid = !!vestingWalletAddressV1 && vestingWalletAddressV1 !== ADDRESS_ZERO
  const isV2Valid = !!vestingWalletAddressV2 && vestingWalletAddressV2 !== ADDRESS_ZERO
  const vestingWalletAddress = isV1Valid ? vestingWalletAddressV1 : vestingWalletAddressV2

  const isV2Wallet = isV2Valid && !isV1Valid

  // Check if wallet is staked in escrow
  const activeFactoryAddress = isV1Valid ? factoryAddress : isV2Valid ? factoryV2Address : undefined

  const escrowAddress = SUMMER_VESTING_WALLETS_ESCROW_ADDRESSES[environment][Number(chainId)]
  const hasEscrow = !!escrowAddress && escrowAddress !== ADDRESS_ZERO

  const { data: userStakedFactories } = useReadContract({
    abi: summerVestingWalletEscrowAbi,
    address: hasEscrow ? (escrowAddress as `0x${string}`) : undefined,
    functionName: 'userStakedVestingFactories',
    args: queryAddress ? [queryAddress] : undefined,
    query: { enabled: !!hasEscrow && !!queryAddress },
  })

  const isStaked = useMemo(() => {
    if (!activeFactoryAddress || !userStakedFactories || userStakedFactories.length === 0)
      return false
    return userStakedFactories.some((f) => f.toLowerCase() === activeFactoryAddress.toLowerCase())
  }, [activeFactoryAddress, userStakedFactories])

  // Underlying token for this vesting wallet
  const { data: tokenAddress } = useReadContract({
    abi: isV2Wallet ? summerVestingWalletV2Abi : summerVestingWalletAbi,
    address: vestingWalletAddress as `0x${string}` | undefined,
    functionName: 'token',
    query: { enabled: !!vestingWalletAddress },
  })

  // Check if V2 wallet is recalled
  const { data: isRecalled } = useReadContract({
    abi: summerVestingWalletV2Abi,
    address: vestingWalletAddress as `0x${string}` | undefined,
    functionName: 'isRecalled',
    query: { enabled: !!vestingWalletAddress && isV2Wallet },
  })

  const { data: tokenSymbol } = useReadContract({
    abi: erc20Abi,
    address: tokenAddress as `0x${string}` | undefined,
    functionName: 'symbol',
    query: { enabled: !!tokenAddress },
  })

  const { data: tokenDecimals } = useReadContract({
    abi: erc20Abi,
    address: tokenAddress as `0x${string}` | undefined,
    functionName: 'decimals',
    query: { enabled: !!tokenAddress },
  })

  // Vesting type & time-based allocation
  const { data: vestingType } = useReadContract({
    abi: isV2Wallet ? summerVestingWalletV2Abi : summerVestingWalletAbi,
    address: vestingWalletAddress as `0x${string}` | undefined,
    functionName: isV2Wallet ? 'vestingParams' : 'getVestingType',
    query: { enabled: !!vestingWalletAddress },
  })

  // // Extract V2 params by tuple position to avoid ABI name mismatches
  // const v2CliffAmount = useMemo(() => {
  //   if (!isV2Wallet || vestingType === undefined) return null
  //   return extractVestingParam(vestingType, 1, 'cliffAmount') ?? BigInt(0)
  // }, [isV2Wallet, vestingType])

  const v2TotalVestingAmount = useMemo(() => {
    if (!isV2Wallet || vestingType === undefined) return null
    return extractVestingParam(vestingType, 3, 'totalVestingAmount') ?? BigInt(0)
  }, [isV2Wallet, vestingType])

  // For V1 only: read time-based amount directly; for V2 we reuse vestingParams from above
  const { data: timeBasedAmount } = useReadContract({
    abi: summerVestingWalletAbi,
    address: vestingWalletAddress as `0x${string}` | undefined,
    functionName: 'timeBasedVestingAmount',
    query: { enabled: !!vestingWalletAddress && !isV2Wallet },
  })

  // Vested now and releasable
  const { data: releasableNow } = useReadContract({
    abi: isV2Wallet ? summerVestingWalletV2Abi : summerVestingWalletAbi,
    address: vestingWalletAddress as `0x${string}` | undefined,
    functionName: 'releasable',
    args: tokenAddress ? [tokenAddress as `0x${string}`] : undefined,
    query: { enabled: !!vestingWalletAddress && !!tokenAddress },
  })

  const { data: releasedTotal } = useReadContract({
    abi: isV2Wallet ? summerVestingWalletV2Abi : summerVestingWalletAbi,
    address: vestingWalletAddress as `0x${string}` | undefined,
    functionName: 'released',
    args: tokenAddress ? [tokenAddress as `0x${string}`] : undefined,
    query: { enabled: !!vestingWalletAddress && !!tokenAddress },
  })

  const { writeContract, data: txHash, isPending } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash })

  const decimals = useMemo(
    () => (typeof tokenDecimals === 'number' ? tokenDecimals : 18),
    [tokenDecimals],
  )

  const formattedReleasable = useMemo(
    () => formatDecimalOutput((releasableNow as bigint) ?? BigInt(0), decimals),
    [releasableNow, decimals],
  )
  const formattedReleased = useMemo(
    () => formatDecimalOutput((releasedTotal as bigint) ?? BigInt(0), decimals),
    [releasedTotal, decimals],
  )

  const isLookupSameAsConnected = useMemo(() => {
    if (!lookupAddress) return true
    if (!address) return false
    try {
      return getAddress(lookupAddress) === getAddress(address)
    } catch {
      return false
    }
  }, [lookupAddress, address])

  const canClaim = Boolean(
    isConnected &&
      isLookupSameAsConnected &&
      vestingWalletAddress &&
      tokenAddress &&
      (releasableNow as bigint) > BigInt(0) &&
      !(isV2Wallet && isRecalled) &&
      !isStaked,
  )

  const onClaim = () => {
    if (!canClaim || !vestingWalletAddress || !tokenAddress) return

    if (isV2Wallet) {
      writeContract({
        abi: summerVestingWalletV2Abi,
        address: vestingWalletAddress as `0x${string}`,
        functionName: 'release',
        args: [tokenAddress as `0x${string}`],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: address,
      })
      return
    }

    writeContract({
      abi: summerVestingWalletAbi,
      address: vestingWalletAddress as `0x${string}`,
      functionName: 'release',
      args: [tokenAddress as `0x${string}`],
      chain: VIEM_CHAIN_ENTITIES[chainId],
      account: address,
    })
  }

  // Fetch dynamic arrays goalAmounts + goalsReached by probing indices via multicall
  const publicClient = usePublicClient({ chainId: Number(chainId) })
  const [goals, setGoals] = useState<{ amount: bigint; reached: boolean; description?: string }[]>(
    [],
  )

  useEffect(() => {
    let cancelled = false
    async function loadGoals() {
      if (!publicClient || !vestingWalletAddress) return

      const client = publicClient

      if (isV2Wallet) {
        // V2 contract: use performanceGoals function
        try {
          const maxProbe = 32 // reasonable upper bound; can raise if needed
          const indices = Array.from({ length: maxProbe }, (_, i) => BigInt(i + 1)) // V2 uses 1-indexed goals

          const goalCalls = indices.map((i) => ({
            address: vestingWalletAddress as `0x${string}`,
            abi: summerVestingWalletV2Abi,
            functionName: 'performanceGoals' as const,
            args: [i],
          }))

          const goalResponse = await (
            client as unknown as {
              multicall: (params: {
                contracts: typeof goalCalls
                allowFailure: true
              }) => Promise<MulticallResult<readonly [bigint, boolean, string]>[]>
            }
          ).multicall({ contracts: goalCalls, allowFailure: true })

          const goalRes = goalResponse ?? []

          const items: { amount: bigint; reached: boolean; description?: string }[] = []
          for (let i = 0; i < maxProbe; i++) {
            const goal = goalRes[i]
            if (goal?.status === 'success' && goal.result) {
              const parsed = parseV2GoalResult(goal.result)
              if (!parsed || parsed.amount === BigInt(0)) break
              items.push(parsed)
            } else {
              break
            }
          }
          if (!cancelled) setGoals(items)
        } catch (error) {
          console.error('Failed to load V2 performance goals', error)
          // Non-fatal; just leave goals empty
          if (!cancelled) setGoals([])
        }
      } else {
        // V1 contract: use goalAmounts + goalsReached
        const maxProbe = 32 // reasonable upper bound; can raise if needed
        const indices = Array.from({ length: maxProbe }, (_, i) => BigInt(i))
        const amountCalls = indices.map((i) => ({
          address: vestingWalletAddress as `0x${string}`,
          abi: summerVestingWalletAbi,
          functionName: 'goalAmounts' as const,
          args: [i],
        }))
        const reachedCalls = indices.map((i) => ({
          address: vestingWalletAddress as `0x${string}`,
          abi: summerVestingWalletAbi,
          functionName: 'goalsReached' as const,
          args: [i],
        }))

        try {
          const [amountResponse, reachedResponse] = await Promise.all([
            (
              client as unknown as {
                multicall: (params: {
                  contracts: typeof amountCalls
                  allowFailure: true
                }) => Promise<MulticallResult<bigint>[]>
              }
            ).multicall({ contracts: amountCalls, allowFailure: true }),
            (
              client as unknown as {
                multicall: (params: {
                  contracts: typeof reachedCalls
                  allowFailure: true
                }) => Promise<MulticallResult<boolean>[]>
              }
            ).multicall({ contracts: reachedCalls, allowFailure: true }),
          ])

          const amountRes = amountResponse ?? []
          const reachedRes = reachedResponse ?? []

          const items: { amount: bigint; reached: boolean; description?: string }[] = []
          for (let i = 0; i < maxProbe; i++) {
            const a = amountRes[i]
            const r = reachedRes[i]
            if (a?.status === 'success' && r?.status === 'success') {
              const amountValue = toBigIntOrNull(a.result) ?? BigInt(0)
              const reachedValueRaw = r.result
              const reachedValue =
                typeof reachedValueRaw === 'boolean' ? reachedValueRaw : Boolean(reachedValueRaw)

              items.push({
                amount: amountValue,
                reached: reachedValue,
              })
            } else {
              break
            }
          }
          if (!cancelled) setGoals(items)
        } catch (error) {
          console.error('Failed to load V1 goal data', error)
          // Non-fatal; just leave goals empty
          if (!cancelled) setGoals([])
        }
      }
    }
    loadGoals()
    return () => {
      cancelled = true
    }
  }, [publicClient, vestingWalletAddress, isV2Wallet])

  const totalAllocation = useMemo(() => {
    if (isV2Wallet && v2TotalVestingAmount !== null) return v2TotalVestingAmount
    const timeBased = (timeBasedAmount as bigint) ?? BigInt(0)
    const goalsSum = goals.reduce((acc, g) => acc + (g.amount ?? BigInt(0)), BigInt(0))
    return timeBased + goalsSum
  }, [isV2Wallet, v2TotalVestingAmount, timeBasedAmount, goals])

  const progressPercent = useMemo(() => {
    if (totalAllocation === BigInt(0)) return 0
    const released = (releasedTotal as bigint) ?? BigInt(0)
    return Number((released * BigInt(10000)) / totalAllocation) / 100
  }, [totalAllocation, releasedTotal])

  const remainingAmount = useMemo(() => {
    const released = (releasedTotal as bigint) ?? BigInt(0)
    return totalAllocation - released
  }, [totalAllocation, releasedTotal])

  return (
    <main className="min-h-screen bg-charcoal-900 p-8">
      <div className="max-w-4xl mx-auto">
        {/* Design nav: glass bar, search, chain selector, connect */}
        <div className="glass rounded-xl p-4 mb-8 flex flex-col md:flex-row md:items-center gap-4">
          <div className="flex items-center gap-3">
            <button
              onClick={() => router.back()}
              className="text-slate-400 hover:text-white transition-colors text-sm"
            >
              ← Back
            </button>
            <Link
              href={`/vesting/${chainId}/batch`}
              className="text-slate-400 hover:text-white text-sm"
            >
              Batch
            </Link>
          </div>
          <div className="flex-1 relative">
            <span className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500 text-sm">
              🔍
            </span>
            <input
              value={inputAddress}
              onChange={(e) => setInputAddress(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && onFetchAddress()}
              placeholder="Enter address to view..."
              className="w-full py-2.5 pl-10 pr-4 rounded-lg bg-white/5 border border-white/10 text-white placeholder-slate-500 text-sm focus:ring-2 focus:ring-primary/50 focus:border-primary"
            />
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={onFetchAddress}
              className="px-4 py-2.5 rounded-lg bg-primary hover:bg-primary/90 text-white font-medium text-sm"
            >
              Fetch
            </button>
            {lookupAddress && (
              <button
                onClick={onClearOverride}
                className="px-4 py-2.5 rounded-lg bg-white/10 hover:bg-white/20 text-white text-sm"
              >
                Clear
              </button>
            )}
            <ChainPills
              selectedChain={chainId}
              onChange={handleChainChange}
              chains={VALID_CHAINS}
            />
            <ConnectButton />
          </div>
        </div>
        <div className="mb-4 text-sm">
          {addressError && <span className="text-red-400">{addressError}</span>}
          {!addressError && (
            <span className="text-slate-500">
              Viewing: <span className="text-slate-300 font-mono">{queryAddress ?? '—'}</span>
            </span>
          )}
        </div>
        {!isLookupSameAsConnected && isConnected && (
          <div className="mb-4 text-amber-400 text-sm">
            To claim, connect the same address or clear the override.
          </div>
        )}

        {!isBase && (
          <div className="mb-6 p-4 rounded-xl border border-amber-500/30 bg-amber-500/10 text-amber-200 text-sm">
            Please switch to Base network to manage vesting.
          </div>
        )}

        {!isConnected && (
          <div className="mb-6 p-4 rounded-xl border border-primary/30 bg-primary/10 text-primary text-sm">
            Connect your wallet to claim. You can still fetch any address to view details.
          </div>
        )}

        {isV2Wallet && isRecalled && (
          <div className="mb-6 p-4 rounded-xl border border-red-500/30 bg-red-500/10 text-red-200 text-sm">
            ⚠️ This vesting wallet has been recalled. No more tokens can be claimed.
          </div>
        )}

        {isStaked && (
          <div className="mb-6 p-4 rounded-xl border border-amber-500/30 bg-amber-500/10 text-amber-200 text-sm">
            ⚠️ Your vesting wallet is staked. You cannot claim while staked.{' '}
            <Link
              href={`/vesting-staking/${chainId}`}
              className="underline font-bold hover:text-white"
            >
              Go to Staking to unstake first.
            </Link>
          </div>
        )}

        {/* Metrics row */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
          <StatCard
            label="Total Vested"
            value={
              vestingWalletAddress
                ? `${formatDecimalOutput(totalAllocation, decimals)} ${(tokenSymbol as string) || ''}`
                : '—'
            }
          />
          <StatCard
            label="Claimable Now"
            value={
              vestingWalletAddress ? `${formattedReleasable} ${(tokenSymbol as string) || ''}` : '—'
            }
            highlight
          />
          <StatCard label="Next Release" value="—" suffix="(N/A)" />
        </div>

        {/* Vesting Details + Claim */}
        <div className="grid gap-6 md:grid-cols-2 mb-8">
          <GlassCard>
            <h2 className="text-lg font-semibold text-white mb-6">Vesting Details</h2>
            <div className="space-y-3">
              <div>
                <p className="text-sm text-slate-500 mb-1">Contract</p>
                <p className="font-mono text-slate-300 break-all text-sm">
                  {vestingWalletAddress ? (vestingWalletAddress as string) : '—'}
                </p>
              </div>
              {totalAllocation > BigInt(0) && (
                <div>
                  <div className="flex justify-between text-sm mb-2">
                    <span className="text-slate-500">Progress</span>
                    <span className="text-white">{progressPercent.toFixed(1)}%</span>
                  </div>
                  <ProgressBar value={progressPercent} max={100} />
                  <p className="text-xs text-slate-500 mt-2">
                    Remaining: {formatDecimalOutput(remainingAmount, decimals)}{' '}
                    {(tokenSymbol as string) || ''}
                  </p>
                </div>
              )}
            </div>
          </GlassCard>

          <GlassCard>
            <h2 className="text-lg font-semibold text-white mb-4">Claim</h2>
            <div className="space-y-4">
              <div>
                <p className="text-sm text-slate-500 mb-1">Released</p>
                <p className="text-2xl font-bold text-white">
                  {formattedReleased} {(tokenSymbol as string) || ''}
                </p>
              </div>

              <button
                onClick={onClaim}
                disabled={!canClaim || isPending || isConfirming}
                className={`w-full py-3 rounded-xl font-semibold transition-all ${
                  canClaim && !isPending && !isConfirming
                    ? 'bg-primary hover:bg-primary/90 text-white neon-glow'
                    : 'bg-white/10 text-slate-500 cursor-not-allowed'
                }`}
              >
                {isPending ? 'Submitting…' : isConfirming ? 'Confirming…' : 'Claim now'}
              </button>

              {isSuccess && (
                <div className="p-3 rounded-xl bg-green-500/20 border border-green-500/30 text-green-200 text-sm">
                  Success! Your tokens are on the way.
                </div>
              )}
            </div>
          </GlassCard>
        </div>

        {/* Release Milestones */}
        <GlassCard>
          <h2 className="text-lg font-semibold text-white mb-6">Release Milestones</h2>
          {!isV2Wallet && vestingType !== 0 && (
            <div className="text-slate-500">No goals for this vesting type.</div>
          )}
          {(isV2Wallet || (!isV2Wallet && vestingType === 0)) && (
            <div className="space-y-3">
              {goals.length === 0 && <div className="text-slate-500">No goals found.</div>}
              {goals.map((g, idx) => (
                <div
                  key={idx}
                  className="flex items-center justify-between gap-3 p-4 rounded-xl bg-white/5 border border-white/5"
                >
                  <div>
                    <span className="text-white font-medium">Goal #{idx + 1}</span>
                    {g.description && (
                      <div className="text-sm text-slate-500 mt-1">{g.description}</div>
                    )}
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="text-slate-300">
                      {formatDecimalOutput(g.amount ?? BigInt(0), decimals)}{' '}
                      {(tokenSymbol as string) || ''}
                    </span>
                    <span
                      className={`px-2 py-0.5 rounded-lg text-xs font-medium ${
                        g.reached
                          ? 'bg-green-500/20 text-green-400'
                          : 'bg-slate-500/20 text-slate-400'
                      }`}
                    >
                      {g.reached ? 'Reached' : 'Pending'}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </GlassCard>
      </div>
    </main>
  )
}

export default function VestingPage() {
  return (
    <Suspense
      fallback={
        <main className="min-h-screen bg-charcoal-900 p-8 flex items-center justify-center">
          <div className="glass rounded-xl p-8 animate-pulse">
            <div className="h-6 w-48 bg-white/10 rounded mb-4" />
            <div className="h-4 w-32 bg-white/10 rounded" />
          </div>
        </main>
      }
    >
      <VestingContent />
    </Suspense>
  )
}
