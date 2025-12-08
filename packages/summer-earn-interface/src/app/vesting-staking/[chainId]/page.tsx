'use client'

import { useEffect, useMemo, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { toast } from 'sonner'
import { erc20Abi } from 'viem'
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useWaitForTransactionReceipt,
  useWriteContract,
} from 'wagmi'

import { summerVestingWalletFactoryAbi } from '@/abis/SummerVestingWalletFactory'
import { MAX_UINT256, ZERO_ADDRESS } from '@/common/constants'
import { formatAddress } from '@/utils/address'

import { summerVestingWalletAbi } from '../../../abis/SummerVestingWallet'
import { summerVestingWalletEscrowAbi } from '../../../abis/SummerVestingWalletEscrow'
import {
  STAKED_SUMMER_TOKEN_ADDRESSES,
  SUMMER_TOKEN_ADDRESSES,
  SUMMER_VESTING_WALLETS_ESCROW_ADDRESSES,
} from '../../../config/environments'
import { useEnvironment } from '../../../hooks/useEnvironment'
import { useSyncWalletChain } from '../../../hooks/useSyncWalletChain'
import type { ChainId } from '../../../types'
import { formatDecimalOutput } from '../../../utils/decimals'

type ActionType = 'transfer' | 'stake' | 'unstake' | 'approve' | null

type FlowState =
  | 'unavailable'
  | 'needsOwnership'
  | 'readyToStake'
  | 'stakedNeedsApproval'
  | 'stakedReadyToUnstake'

export default function VestingStakingPage() {
  const params = useParams()
  const router = useRouter()
  const chainId = params.chainId as ChainId

  const { environment } = useEnvironment()
  const { address, isConnected, chain } = useAccount()
  const numericChainId = Number(chainId)
  const publicClient = usePublicClient({ chainId: numericChainId })

  useSyncWalletChain(chainId)

  const summerTokenAddress = SUMMER_TOKEN_ADDRESSES[environment]?.[numericChainId]
  const escrowAddress = SUMMER_VESTING_WALLETS_ESCROW_ADDRESSES[environment]?.[numericChainId]
  const xSummerAddress = STAKED_SUMMER_TOKEN_ADDRESSES[environment]?.[numericChainId]

  const hasSummer = summerTokenAddress !== ZERO_ADDRESS
  const hasEscrow = escrowAddress !== ZERO_ADDRESS
  const hasXSummer = xSummerAddress !== ZERO_ADDRESS && hasEscrow

  // Factories configured in escrow
  const {
    data: factoriesData,
    isLoading: isFactoriesLoading,
    refetch: refetchFactories,
  } = useReadContract({
    abi: summerVestingWalletEscrowAbi,
    address: hasEscrow ? escrowAddress : undefined,
    functionName: 'vestingFactories',
    query: {
      enabled: hasEscrow,
    },
  })

  const factories = useMemo(
    () => (factoriesData || []).filter((f) => f && f.toLowerCase() !== ZERO_ADDRESS.toLowerCase()),
    [factoriesData],
  )

  const [vestingWallet, setVestingWallet] = useState<`0x${string}` | undefined>(undefined)
  const [factoryForWallet, setFactoryForWallet] = useState<`0x${string}` | undefined>(undefined)
  const [isVestingWalletLoading, setIsVestingWalletLoading] = useState(false)
  const [hasMultipleVestingWallets, setHasMultipleVestingWallets] = useState(false)

  // Resolve user's vesting wallet by querying all factories and taking the first non-zero result.
  // If multiple non-zero wallets are found, we still use the first but surface a warning in the UI.
  useEffect(() => {
    let cancelled = false

    async function loadVestingWallet() {
      if (!publicClient || !address || factories.length === 0) {
        if (!cancelled) {
          setVestingWallet(undefined)
          setFactoryForWallet(undefined)
          setHasMultipleVestingWallets(false)
        }
        return
      }

      setIsVestingWalletLoading(true)
      try {
        const contracts = factories.map((factory) => ({
          address: factory,
          abi: summerVestingWalletFactoryAbi,
          functionName: 'vestingWallets',
          args: [address],
        }))
        // @ts-expect-error - wagmi types are not up to date
        const result = await publicClient.multicall({
          contracts,
          allowFailure: true,
        })

        if (cancelled) return

        const nonZero: { wallet: `0x${string}`; factory: `0x${string}` }[] = []

        for (let i = 0; i < result.length; i++) {
          const entry = result[i]
          if (entry?.status === 'success' && entry.result) {
            const wallet = entry.result
            if (wallet.toLowerCase() !== ZERO_ADDRESS.toLowerCase()) {
              nonZero.push({ wallet, factory: factories[i] })
            }
          }
        }

        if (nonZero.length === 0) {
          setVestingWallet(undefined)
          setFactoryForWallet(undefined)
          setHasMultipleVestingWallets(false)
        } else {
          setVestingWallet(nonZero[0].wallet)
          setFactoryForWallet(nonZero[0].factory)
          setHasMultipleVestingWallets(nonZero.length > 1)
        }
      } catch (error) {
        console.error('Failed to resolve vesting wallets', error)
        if (!cancelled) {
          setVestingWallet(undefined)
          setFactoryForWallet(undefined)
          setHasMultipleVestingWallets(false)
        }
      } finally {
        if (!cancelled) {
          setIsVestingWalletLoading(false)
        }
      }
    }

    loadVestingWallet()

    return () => {
      cancelled = true
    }
  }, [publicClient, address, factories])

  // Current vesting wallet owner
  const { data: vestingOwner, refetch: refetchVestingOwner } = useReadContract({
    abi: summerVestingWalletAbi,
    address: vestingWallet,
    functionName: 'owner',
    query: {
      enabled: Boolean(vestingWallet),
    },
  })

  // User staked factories
  const { data: userStakedFactories, refetch: refetchUserStakedFactories } = useReadContract({
    abi: summerVestingWalletEscrowAbi,
    address: hasEscrow ? escrowAddress : undefined,
    functionName: 'userStakedVestingFactories',
    args: address && hasEscrow ? [address] : undefined,
    query: {
      enabled: Boolean(address && hasEscrow),
    },
  })

  const isOwnedByEscrow = useMemo(() => {
    if (!escrowAddress || !vestingOwner) return false
    return vestingOwner.toLowerCase() === escrowAddress.toLowerCase()
  }, [escrowAddress, vestingOwner])

  const isFactoryStaked = useMemo(() => {
    if (!factoryForWallet || !userStakedFactories || userStakedFactories.length === 0) return false
    return userStakedFactories.some((f) => f.toLowerCase() === factoryForWallet.toLowerCase())
  }, [factoryForWallet, userStakedFactories])

  // SUMMER token metadata and vesting wallet balance
  const { data: summerSymbol } = useReadContract({
    abi: erc20Abi,
    address: hasSummer ? summerTokenAddress : undefined,
    functionName: 'symbol',
    query: {
      enabled: hasSummer,
    },
  })

  const { data: summerDecimals } = useReadContract({
    abi: erc20Abi,
    address: hasSummer ? summerTokenAddress : undefined,
    functionName: 'decimals',
    query: {
      enabled: hasSummer,
    },
  })

  const { data: summerVestingBalance } = useReadContract({
    abi: erc20Abi,
    address: hasSummer ? summerTokenAddress : undefined,
    functionName: 'balanceOf',
    args: vestingWallet && hasSummer ? [vestingWallet] : undefined,
    query: {
      enabled: Boolean(vestingWallet && hasSummer),
    },
  })

  const summerTokenDecimals = useMemo(
    () => (typeof summerDecimals === 'number' ? summerDecimals : 18),
    [summerDecimals],
  )

  const summerVestingBalanceValue = (summerVestingBalance ?? 0n) as bigint

  const formattedSummerVestingBalance = useMemo(
    () => formatDecimalOutput(summerVestingBalanceValue, summerTokenDecimals),
    [summerVestingBalanceValue, summerTokenDecimals],
  )

  // xSUMR token metadata, balance and allowance
  const { data: stakedTokenSymbol } = useReadContract({
    abi: erc20Abi,
    address: hasXSummer ? xSummerAddress : undefined,
    functionName: 'symbol',
    query: {
      enabled: hasXSummer,
    },
  })

  const { data: xSummerDecimals } = useReadContract({
    abi: erc20Abi,
    address: hasXSummer ? xSummerAddress : undefined,
    functionName: 'decimals',
    query: {
      enabled: hasXSummer,
    },
  })

  const { data: xSummerBalance, refetch: refetchXSummerBalance } = useReadContract({
    abi: erc20Abi,
    address: hasXSummer ? xSummerAddress : undefined,
    functionName: 'balanceOf',
    args: address && hasXSummer ? [address] : undefined,
    query: {
      enabled: Boolean(address && hasXSummer),
    },
  })

  const { data: xSummerAllowance, refetch: refetchXSummerAllowance } = useReadContract({
    abi: erc20Abi,
    address: hasXSummer ? xSummerAddress : undefined,
    functionName: 'allowance',
    args: address && hasXSummer && hasEscrow ? [address, escrowAddress] : undefined,
    query: {
      enabled: Boolean(address && hasXSummer && hasEscrow),
    },
  })

  const xDecimals = useMemo(
    () => (typeof xSummerDecimals === 'number' ? xSummerDecimals : 18),
    [xSummerDecimals],
  )

  const xSummerBalanceValue = (xSummerBalance ?? 0n) as bigint
  const xSummerAllowanceValue = (xSummerAllowance ?? 0n) as bigint

  const needsXSummerApproval = useMemo(() => {
    if (xSummerBalanceValue === 0n) return false
    return xSummerAllowanceValue < xSummerBalanceValue
  }, [xSummerAllowanceValue, xSummerBalanceValue])

  const formattedStakedBalance = useMemo(
    () => formatDecimalOutput(xSummerBalanceValue, xDecimals),
    [xSummerBalanceValue, xDecimals],
  )

  // Writes
  const { writeContract, data: txHash, isPending } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  })
  const [currentAction, setCurrentAction] = useState<ActionType>(null)

  const isBusy = isPending || isConfirming

  const handleTransferOwnership = async () => {
    if (!vestingWallet || !escrowAddress || !address) return
    try {
      setCurrentAction('transfer')
      writeContract({
        address: vestingWallet,
        abi: summerVestingWalletAbi,
        functionName: 'transferOwnership',
        args: [escrowAddress],
        account: address,
        chain,
      })
    } catch (error: any) {
      setCurrentAction(null)
      toast.error(error?.shortMessage || error?.message || 'Failed to transfer ownership')
    }
  }

  const handleStake = async () => {
    if (!escrowAddress || !factoryForWallet || !address) return
    try {
      setCurrentAction('stake')
      writeContract({
        address: escrowAddress,
        abi: summerVestingWalletEscrowAbi,
        functionName: 'stakeVesting',
        args: [[factoryForWallet]],
        account: address,
        chain,
      })
    } catch (error: any) {
      setCurrentAction(null)
      toast.error(error?.shortMessage || error?.message || 'Failed to stake vesting wallet')
    }
  }

  const handleUnstake = async () => {
    if (!escrowAddress || !factoryForWallet || !address) return
    try {
      setCurrentAction('unstake')
      writeContract({
        address: escrowAddress,
        abi: summerVestingWalletEscrowAbi,
        functionName: 'unstakeVesting',
        args: [[factoryForWallet]],
        account: address,
        chain,
      })
    } catch (error: any) {
      setCurrentAction(null)
      toast.error(error?.shortMessage || error?.message || 'Failed to unstake vesting wallet')
    }
  }

  const handleApproveXSummer = async () => {
    if (!xSummerAddress || !escrowAddress || !address) return
    try {
      setCurrentAction('approve')
      writeContract({
        address: xSummerAddress,
        abi: erc20Abi,
        functionName: 'approve',
        args: [escrowAddress, MAX_UINT256],
        account: address,
        chain,
      })
    } catch (error: any) {
      setCurrentAction(null)
      toast.error(error?.shortMessage || error?.message || 'Failed to approve xSUMR')
    }
  }

  useEffect(() => {
    if (isSuccess) {
      toast.success('Transaction confirmed')
      setCurrentAction(null)
      refetchFactories?.()
      refetchUserStakedFactories?.()
      refetchVestingOwner?.()
      refetchXSummerBalance?.()
      refetchXSummerAllowance?.()
    }
  }, [
    isSuccess,
    refetchFactories,
    refetchUserStakedFactories,
    refetchVestingOwner,
    refetchXSummerBalance,
    refetchXSummerAllowance,
  ])

  const noFactoriesConfigured = hasEscrow && !isFactoriesLoading && factories.length === 0
  const noVestingWalletFound =
    hasEscrow && factories.length > 0 && isConnected && !isVestingWalletLoading && !vestingWallet

  const flowState: FlowState = useMemo(() => {
    // Base availability: must be connected, not busy, have a vesting wallet and escrow deployed to the current stage environment.
    if (!isConnected || isBusy || !vestingWallet || !escrowAddress) {
      return 'unavailable'
    }

    // Step 1: ownership transfer not yet done.
    if (!isOwnedByEscrow) {
      return 'needsOwnership'
    }

    // From here on, ownership is with escrow. For step 2 we also need a mapped factory.
    if (!factoryForWallet) {
      return 'unavailable'
    }

    // Not staked yet → can stake.
    if (!isFactoryStaked) {
      return 'readyToStake'
    }

    // Staked, but needs xSUMR approval before we can unstake.
    if (needsXSummerApproval) {
      return 'stakedNeedsApproval'
    }

    // Fully staked and approved, ready to unstake.
    return 'stakedReadyToUnstake'
  }, [
    isConnected,
    isBusy,
    vestingWallet,
    escrowAddress,
    factoryForWallet,
    isOwnedByEscrow,
    isFactoryStaked,
    needsXSummerApproval,
  ])

  const canTransferOwnership = flowState === 'needsOwnership'
  const canStake = flowState === 'readyToStake'
  const canApproveXSummer = flowState === 'stakedNeedsApproval'
  const canUnstake = flowState === 'stakedReadyToUnstake'

  const step2Disabled = flowState === 'needsOwnership' || flowState === 'unavailable'

  return (
    <main className="min-h-screen bg-gradient-to-b from-black via-charcoal-900 to-black p-6 md:p-10">
      <div className="max-w-4xl mx-auto space-y-6">
        <div className="flex items-center justify-between gap-4 mb-2">
          <div className="flex items-center gap-4">
            <button
              onClick={() => router.back()}
              className="px-4 py-2 bg-charcoal-800 hover:bg-gray-700 text-white rounded-lg border border-white/10"
            >
              ← Back
            </button>
            <div>
              <h1 className="text-3xl md:text-4xl font-extrabold text-white">
                Vesting Wallet Staking
              </h1>
              <p className="text-sm text-gray-400">
                Stake your vesting wallet in two simple steps: transfer ownership, then stake.
              </p>
            </div>
          </div>
          <span className="px-2 py-1 rounded-full border border-white/10 text-xs uppercase tracking-wide text-gray-300">
            {environment}
          </span>
        </div>

        {!isConnected && (
          <div className="rounded-2xl border border-blue-600 bg-blue-900/40 text-blue-100 p-4 text-sm">
            Connect your wallet to discover your vesting wallet and manage staking.
          </div>
        )}

        {!hasEscrow && (
          <div className="rounded-2xl border border-yellow-600 bg-yellow-900/40 text-yellow-100 p-4 text-sm">
            Vesting staking is not available on this chain and environment.
          </div>
        )}

        {hasEscrow && noFactoriesConfigured && (
          <div className="rounded-2xl border border-yellow-600 bg-yellow-900/40 text-yellow-100 p-4 text-sm">
            no factories configured
          </div>
        )}

        {hasMultipleVestingWallets && (
          <div className="rounded-2xl border border-red-600 bg-red-900/40 text-red-100 p-4 text-sm">
            We detected multiple vesting wallets associated with this address. Please contact us on
            Discord so we can investigate why you have multiple vesting wallets.
          </div>
        )}

        {hasEscrow && !noFactoriesConfigured && isConnected && noVestingWalletFound && (
          <div className="rounded-2xl border border-gray-700 bg-charcoal-900 text-gray-200 p-4 text-sm">
            No vesting wallet associated with this address. Once a vesting wallet is created for
            you, it will appear here automatically.
          </div>
        )}

        {hasEscrow && factories.length > 0 && vestingWallet && (
          <div className="space-y-4">
            {/* Step 1: Transfer ownership */}
            <section className="rounded-2xl p-6 bg-charcoal-900 border border-white/10 space-y-4">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <div className="text-xs uppercase tracking-wide text-gray-400">Step 1</div>
                  <h2 className="text-xl font-semibold text-white">Transfer ownership to escrow</h2>
                </div>
                <div
                  className={`px-3 py-1 rounded-full text-xs font-medium ${
                    isOwnedByEscrow
                      ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/40'
                      : 'bg-amber-500/10 text-amber-300 border border-amber-500/40'
                  }`}
                >
                  {isOwnedByEscrow ? 'Completed' : 'Required'}
                </div>
              </div>

              <div className="grid gap-3 text-sm text-gray-300 md:grid-cols-2">
                <div className="space-y-1">
                  <div className="text-xs text-gray-400">Vesting wallet</div>
                  <div className="font-mono text-blue-300 break-all">{vestingWallet}</div>
                </div>
                <div className="space-y-1">
                  <div className="text-xs text-gray-400">Escrow</div>
                  <div className="font-mono text-purple-300 break-all">
                    {escrowAddress ? escrowAddress : '—'}
                  </div>
                </div>
                <div className="space-y-1">
                  <div className="text-xs text-gray-400">Current owner</div>
                  <div className={isOwnedByEscrow ? 'text-emerald-400' : 'text-amber-300'}>
                    {isOwnedByEscrow ? 'Escrow' : `You (${formatAddress(address)})`}
                  </div>
                </div>
                <div className="space-y-1">
                  <div className="text-xs text-gray-400">Vesting wallet SUMMER balance</div>
                  <div className="text-white">
                    {hasSummer
                      ? `${formattedSummerVestingBalance} ${summerSymbol || 'SUMMER'}`
                      : '—'}
                  </div>
                  <div className="text-xs text-gray-500">
                    This is the total SUMMER held by your vesting wallet - it represents the amount
                    of stSUMR you will get after staking.
                  </div>
                </div>
              </div>

              <button
                onClick={handleTransferOwnership}
                disabled={!canTransferOwnership}
                className={`mt-2 inline-flex items-center justify-center px-4 py-2 rounded-md text-sm font-semibold ${
                  canTransferOwnership
                    ? 'bg-magenta-600 hover:bg-magenta-700 text-white'
                    : 'bg-gray-700 text-gray-400 cursor-not-allowed'
                }`}
              >
                {currentAction === 'transfer' && isBusy
                  ? 'Transferring ownership...'
                  : 'Transfer Ownership to Escrow'}
              </button>

              <p className="text-xs text-gray-400">
                The escrow must own your vesting wallet before it can be staked. This does not move
                your tokens; it only changes who controls the vesting contract.
              </p>
            </section>

            {/* Step 2: Stake / Unstake */}
            <section className="relative rounded-2xl p-6 bg-charcoal-900 border border-white/10 space-y-4">
              {step2Disabled && (
                <div className="absolute inset-0 z-10 flex flex-col items-center justify-center rounded-2xl bg-black/60 text-center px-6">
                  <div className="text-sm font-medium text-gray-100">
                    Complete Step 1 to continue
                  </div>
                  <div className="mt-1 text-xs text-gray-400 max-w-sm">
                    Once the escrow owns your vesting wallet, you&apos;ll be able to stake and
                    unstake it here.
                  </div>
                </div>
              )}

              <div className={step2Disabled ? 'opacity-40 pointer-events-none select-none' : ''}>
                <div className="flex items-center justify-between gap-4">
                  <div>
                    <div className="text-xs uppercase tracking-wide text-gray-400">Step 2</div>
                    <h2 className="text-xl font-semibold text-white">Stake / Unstake</h2>
                    <p className="text-xs text-gray-400">
                      Stake your vesting wallet into escrow and manage your staked position.
                    </p>
                  </div>
                  <div
                    className={`px-3 py-1 rounded-full text-xs font-medium ${
                      isFactoryStaked
                        ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/40'
                        : 'bg-gray-700/60 text-gray-200 border border-gray-600'
                    }`}
                  >
                    {isFactoryStaked ? 'Staked' : 'Not staked'}
                  </div>
                </div>

                <div className="mt-4 grid gap-4 md:grid-cols-2 text-sm">
                  <div className="space-y-2">
                    <div className="text-xs text-gray-400">Factory</div>
                    <div className="font-mono text-blue-300 break-all">
                      {factoryForWallet ? factoryForWallet : '—'}
                    </div>
                    <div className="text-xs text-gray-400 mt-3">Staked token</div>
                    <div className="text-gray-200">
                      {hasXSummer ? (
                        <>
                          {stakedTokenSymbol}{' '}
                          <span className="font-mono text-blue-300">
                            ({formatAddress(xSummerAddress)})
                          </span>
                        </>
                      ) : (
                        'xSUMR not configured for this chain'
                      )}
                    </div>
                  </div>

                  <div className="space-y-2">
                    <div className="text-xs text-gray-400">Your staked token balance</div>
                    <div className="text-2xl font-semibold text-white">
                      {hasXSummer && isConnected ? (
                        <>
                          {formattedStakedBalance}{' '}
                          <span className="text-sm text-gray-400">{stakedTokenSymbol}</span>
                        </>
                      ) : (
                        '—'
                      )}
                    </div>
                    <div className="text-xs text-gray-400 mt-1">
                      This is the balance of all of your staked tokens. It includes both your
                      original staked tokens and ones received for vesting wallet staking.
                    </div>
                  </div>
                </div>

                <div className="mt-4 flex flex-wrap gap-3">
                  {!isFactoryStaked && (
                    <button
                      onClick={handleStake}
                      disabled={!canStake}
                      className={`inline-flex items-center justify-center px-4 py-2 rounded-md text-sm font-semibold ${
                        canStake
                          ? 'bg-magenta-600 hover:bg-magenta-700 text-white'
                          : 'bg-gray-700 text-gray-400 cursor-not-allowed'
                      }`}
                    >
                      {currentAction === 'stake' && isBusy ? 'Staking vesting wallet...' : 'Stake'}
                    </button>
                  )}

                  {isFactoryStaked && hasXSummer && (
                    <>
                      <button
                        onClick={handleApproveXSummer}
                        disabled={!canApproveXSummer}
                        className={`inline-flex items-center justify-center px-4 py-2 rounded-md text-sm font-semibold ${
                          canApproveXSummer
                            ? 'bg-blue-600 hover:bg-blue-700 text-white'
                            : 'bg-gray-700 text-gray-400 cursor-not-allowed'
                        }`}
                      >
                        {currentAction === 'approve' && isBusy
                          ? 'Approving xSUMR...'
                          : 'Approve xSUMR'}
                      </button>
                      <button
                        onClick={handleUnstake}
                        disabled={!canUnstake}
                        className={`inline-flex items-center justify-center px-4 py-2 rounded-md text-sm font-semibold ${
                          canUnstake
                            ? 'bg-red-600 hover:bg-red-700 text-white'
                            : 'bg-gray-700 text-gray-400 cursor-not-allowed'
                        }`}
                      >
                        {currentAction === 'unstake' && isBusy
                          ? 'Unstaking vesting wallet...'
                          : 'Unstake'}
                      </button>
                    </>
                  )}
                </div>

                {isFactoryStaked && hasXSummer && needsXSummerApproval && (
                  <p className="mt-2 text-xs text-yellow-300">
                    To unstake, escrow needs permission to burn your staked tokens. Approve xSUMR
                    first, then you can unstake.
                  </p>
                )}
              </div>
            </section>
          </div>
        )}
      </div>
    </main>
  )
}
