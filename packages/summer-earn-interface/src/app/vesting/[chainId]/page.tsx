'use client'

import { useEffect, useMemo, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { getAddress, isAddress } from 'viem'
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useWaitForTransactionReceipt,
  useWriteContract,
} from 'wagmi'
import { base as baseChain } from 'wagmi/chains'

import { erc20Abi } from '../../../abis/ERC20'
import { summerVestingWalletAbi } from '../../../abis/SummerVestingWallet'
import { summerVestingWalletFactoryAbi } from '../../../abis/SummerVestingWalletFactory'
import { summerVestingWalletFactoryV2Abi } from '../../../abis/SummerVestingWalletFactoryV2'
import { summerVestingWalletV2Abi } from '../../../abis/SummerVestingWalletV2'
import {
  SUMMER_VESTING_WALLET_FACTORY_ADDRESSES,
  SUMMER_VESTING_WALLET_FACTORY_V2_ADDRESSES,
} from '../../../config/environments'
import { useEnvironment } from '../../../hooks/useEnvironment'
import { useSyncWalletChain } from '../../../hooks/useSyncWalletChain'
import type { ChainId } from '../../../types'
import { formatDecimalOutput } from '../../../utils/decimals'

export default function VestingPage() {
  const params = useParams()
  const router = useRouter()
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
  const ADDRESS_ZERO = '0x0000000000000000000000000000000000000000'
  // Use V1 if found, otherwise V2
  const isV1Valid = !!vestingWalletAddressV1 && vestingWalletAddressV1 !== ADDRESS_ZERO
  const isV2Valid = !!vestingWalletAddressV2 && vestingWalletAddressV2 !== ADDRESS_ZERO
  const vestingWalletAddress = isV1Valid ? vestingWalletAddressV1 : vestingWalletAddressV2

  const isV2Wallet = isV2Valid && !isV1Valid

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

  // Extract V2 params by tuple position to avoid ABI name mismatches
  const v2CliffAmount = useMemo(() => {
    if (!isV2Wallet || !vestingType) return null
    const vp: any = vestingType
    const byIndex = vp?.[1]
    const byName = vp?.cliffAmount
    try {
      return BigInt(byIndex ?? byName ?? 0)
    } catch {
      return BigInt(0)
    }
  }, [isV2Wallet, vestingType])

  const v2TotalVestingAmount = useMemo(() => {
    if (!isV2Wallet || !vestingType) return null
    const vp: any = vestingType
    console.log('vp', vp)
    const byIndex = vp?.[3]
    const byName = vp?.totalVestingAmount
    try {
      return BigInt(byIndex ?? byName ?? 0)
    } catch {
      return BigInt(0)
    }
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
      !(isV2Wallet && isRecalled),
  )

  const onClaim = () => {
    if (!canClaim) return
    ;(writeContract as any)({
      abi: isV2Wallet ? summerVestingWalletV2Abi : summerVestingWalletAbi,
      address: vestingWalletAddress as `0x${string}`,
      functionName: 'release',
      args: [tokenAddress as `0x${string}`],
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

      if (isV2Wallet) {
        // V2 contract: use performanceGoals function
        try {
          const pc: any = publicClient
          const maxProbe = 32 // reasonable upper bound; can raise if needed
          const indices = Array.from({ length: maxProbe }, (_, i) => BigInt(i + 1)) // V2 uses 1-indexed goals

          const goalCalls = indices.map((i) => ({
            address: vestingWalletAddress as `0x${string}`,
            abi: summerVestingWalletV2Abi,
            functionName: 'performanceGoals' as const,
            args: [i],
          })) as any[]

          const goalRes = await pc.multicall({ contracts: goalCalls as any, allowFailure: true })

          const items: { amount: bigint; reached: boolean; description?: string }[] = []
          for (let i = 0; i < maxProbe; i++) {
            const goal = goalRes[i]
            if (goal.status === 'success' && goal.result) {
              const result = goal.result as any
              if (result.amount && result.amount > BigInt(0)) {
                items.push({
                  amount: result.amount,
                  reached: result.reached,
                  description: result.description,
                })
              } else {
                break
              }
            } else {
              break
            }
          }
          if (!cancelled) setGoals(items)
        } catch (e) {
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
        })) as any[]
        const reachedCalls = indices.map((i) => ({
          address: vestingWalletAddress as `0x${string}`,
          abi: summerVestingWalletAbi,
          functionName: 'goalsReached' as const,
          args: [i],
        })) as any[]

        try {
          const pc: any = publicClient
          const [amountRes, reachedRes] = await Promise.all([
            pc.multicall({ contracts: amountCalls as any, allowFailure: true }),
            pc.multicall({ contracts: reachedCalls as any, allowFailure: true }),
          ])

          const items: { amount: bigint; reached: boolean; description?: string }[] = []
          for (let i = 0; i < maxProbe; i++) {
            const a = amountRes[i]
            const r = reachedRes[i]
            if (a.status === 'success' && r.status === 'success') {
              items.push({
                amount: a.result as unknown as bigint,
                reached: r.result as unknown as boolean,
              })
            } else {
              break
            }
          }
          if (!cancelled) setGoals(items)
        } catch (e) {
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

  return (
    <main className="min-h-screen bg-gradient-to-b from-black via-gray-900 to-black p-6 md:p-10">
      <div className="max-w-4xl mx-auto">
        <div className="flex items-center gap-4 mb-6">
          <button
            onClick={() => router.back()}
            className="px-4 py-2 bg-gray-800 hover:bg-gray-700 text-white rounded-lg"
          >
            ← Back
          </button>
          <h1 className="text-3xl md:text-4xl font-extrabold text-white">Your Vesting Wallet ✨</h1>
        </div>

        {/* Address override input */}
        <div className="mb-6 rounded-2xl p-4 bg-gray-900 border border-gray-800">
          <div className="flex flex-col md:flex-row md:items-end gap-3">
            <div className="flex-1">
              <label className="block text-sm text-gray-400 mb-1">Address to view</label>
              <input
                value={inputAddress}
                onChange={(e) => setInputAddress(e.target.value)}
                placeholder="0x..."
                className="w-full px-3 py-2 rounded-md bg-gray-800 text-white border border-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-600"
              />
            </div>
            <div className="flex gap-2">
              <button
                onClick={onFetchAddress}
                className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-md"
              >
                Fetch
              </button>
              {lookupAddress && (
                <button
                  onClick={onClearOverride}
                  className="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-md"
                >
                  Clear
                </button>
              )}
            </div>
          </div>
          <div className="mt-2 text-sm">
            {addressError && <span className="text-red-400">{addressError}</span>}
            {!addressError && (
              <span className="text-gray-400">
                Viewing for: <span className="text-gray-200 font-mono">{queryAddress ?? '—'}</span>
              </span>
            )}
          </div>
          {!isLookupSameAsConnected && isConnected && (
            <div className="mt-2 text-yellow-300 text-sm">
              To claim, connect the same address as the one being viewed or clear the override.
            </div>
          )}
        </div>

        {!isBase && (
          <div className="mb-6 p-4 rounded-lg border border-yellow-600 bg-yellow-900/40 text-yellow-200">
            Please switch to Base network to manage vesting.
          </div>
        )}

        {!isConnected && (
          <div className="mb-6 p-4 rounded-lg border border-blue-600 bg-blue-900/40 text-blue-200">
            Optional: connect your wallet to claim. You can still fetch any address above to view
            details.
          </div>
        )}

        {isV2Wallet && isRecalled && (
          <div className="mb-6 p-4 rounded-lg border border-red-600 bg-red-900/40 text-red-200">
            ⚠️ This vesting wallet has been recalled. No more tokens can be claimed.
          </div>
        )}

        <div className="grid gap-6 md:grid-cols-2">
          <div className="rounded-2xl p-6 bg-gray-900 border border-gray-800">
            <h2 className="text-xl font-semibold text-white mb-4">Overview 🌈</h2>
            <div className="space-y-3 text-gray-300">
              <div className="flex items-center justify-between gap-3">
                <span>Factory</span>
                <span className="font-mono text-blue-300 break-all text-right max-w-[60%]">
                  {isV2Wallet ? factoryV2Address : factoryAddress || '—'}
                </span>
              </div>
              <div className="flex items-center justify-between gap-3">
                <span>Your Vesting Wallet</span>
                <span className="font-mono text-green-300 break-all text-right max-w-[60%]">
                  {vestingWalletAddress ? (vestingWalletAddress as string) : '—'}
                </span>
              </div>
              <div className="flex items-center justify-between gap-3">
                <span>Token</span>
                <span className="font-mono text-purple-300 break-all text-right max-w-[60%]">
                  {tokenAddress ? (tokenAddress as string) : '—'}
                </span>
              </div>
              <div className="flex justify-between">
                <span>Symbol</span>
                <span className="text-white">{(tokenSymbol as string) || '—'}</span>
              </div>
            </div>
          </div>

          <div className="rounded-2xl p-6 bg-gray-900 border border-gray-800">
            <h2 className="text-xl font-semibold text-white mb-4">Your Tokens 💰</h2>
            <div className="space-y-4">
              <div className="bg-gray-800/60 rounded-lg p-4">
                <div className="text-gray-400 text-sm">Releasable now</div>
                <div className="text-3xl font-bold text-green-400">
                  {formattedReleasable} {(tokenSymbol as string) || ''}
                </div>
              </div>
              <div className="bg-gray-800/60 rounded-lg p-4">
                <div className="text-gray-400 text-sm">Already claimed</div>
                <div className="text-2xl font-semibold text-blue-300">
                  {formattedReleased} {(tokenSymbol as string) || ''}
                </div>
              </div>

              <button
                onClick={onClaim}
                disabled={!canClaim || isPending || isConfirming}
                className={`w-full py-3 rounded-lg font-semibold transition-colors ${
                  canClaim && !isPending && !isConfirming
                    ? 'bg-green-600 hover:bg-green-700 text-white'
                    : 'bg-gray-700 text-gray-400 cursor-not-allowed'
                }`}
              >
                {isPending ? 'Submitting…' : isConfirming ? 'Confirming…' : 'Claim now 🎉'}
              </button>

              {isSuccess && (
                <div className="p-3 rounded-lg bg-green-900/40 border border-green-700 text-green-200">
                  Success! Your tokens are on the way 🚀
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Vesting details */}
        <div className="grid gap-6 md:grid-cols-2 mt-6">
          <div className="rounded-2xl p-6 bg-gray-900 border border-gray-800">
            <h2 className="text-xl font-semibold text-white mb-4">Vesting Details 🧭</h2>
            <div className="space-y-3 text-gray-300">
              <div className="flex items-center justify-between gap-3">
                <span>Contract Version</span>
                <span className="text-white">{isV2Wallet ? 'V2' : 'V1'}</span>
              </div>
              {!isV2Wallet && (
                <div className="flex items-center justify-between gap-3">
                  <span>Vesting Type</span>
                  <span className="text-white">
                    {vestingType === 0
                      ? 'Team (Goals)'
                      : vestingType === 1
                        ? 'Investor (Time-based only)'
                        : '—'}
                  </span>
                </div>
              )}
              <div className="flex items-center justify-between gap-3">
                <span>Time-based Allocation</span>
                <span className="text-blue-300">
                  {isV2Wallet && v2TotalVestingAmount !== null
                    ? formatDecimalOutput(v2TotalVestingAmount ?? BigInt(0), decimals)
                    : formatDecimalOutput((timeBasedAmount as bigint) ?? BigInt(0), decimals)}{' '}
                  {(tokenSymbol as string) || ''}
                </span>
              </div>
              {isV2Wallet && v2CliffAmount !== null && (
                <div className="flex items-center justify-between gap-3">
                  <span>Cliff Amount</span>
                  <span className="text-purple-300">
                    {formatDecimalOutput(v2CliffAmount ?? BigInt(0), decimals)}{' '}
                    {(tokenSymbol as string) || ''}
                  </span>
                </div>
              )}
            </div>
          </div>

          <div className="rounded-2xl p-6 bg-gray-900 border border-gray-800">
            <h2 className="text-xl font-semibold text-white mb-4">
              Goals {(!isV2Wallet && vestingType === 0) || isV2Wallet ? '🙂/☹️' : ''}
            </h2>
            {!isV2Wallet && vestingType !== 0 && (
              <div className="text-gray-400">No goals for this vesting type.</div>
            )}
            {(isV2Wallet || (!isV2Wallet && vestingType === 0)) && (
              <div className="space-y-3">
                {goals.length === 0 && <div className="text-gray-400">No goals found.</div>}
                {goals.map((g, idx) => (
                  <div
                    key={idx}
                    className="flex items-center justify-between gap-3 bg-gray-800/60 p-3 rounded-lg"
                  >
                    <div className="text-gray-300">
                      Goal #{idx + 1}
                      {g.description && (
                        <div className="text-sm text-gray-400 mt-1">{g.description}</div>
                      )}
                    </div>
                    <div className="flex items-center gap-3">
                      <span className="text-purple-300">
                        {formatDecimalOutput(g.amount ?? BigInt(0), decimals)}{' '}
                        {(tokenSymbol as string) || ''}
                      </span>
                      <span className={g.reached ? 'text-green-400' : 'text-red-400'}>
                        {g.reached ? '🙂' : '☹️'}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </main>
  )
}
