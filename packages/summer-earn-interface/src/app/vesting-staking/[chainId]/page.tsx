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
  AddressDisplay,
  Badge,
  Button,
  EmptyState,
  ErrorState,
  PageHeader,
} from '../../../components/ui'
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
    // Base availability: must be connected and have a vesting wallet and escrow deployed to the current stage environment.
    if (!isConnected || !vestingWallet || !escrowAddress) {
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
    vestingWallet,
    escrowAddress,
    factoryForWallet,
    isOwnedByEscrow,
    isFactoryStaked,
    needsXSummerApproval,
  ])

  const canTransferOwnership = flowState === 'needsOwnership' && !isBusy
  const canStake = flowState === 'readyToStake' && !isBusy
  const canApproveXSummer = flowState === 'stakedNeedsApproval' && !isBusy
  const canUnstake = flowState === 'stakedReadyToUnstake' && !isBusy

  const step2Disabled = flowState === 'needsOwnership' || flowState === 'unavailable'

  return (
    <main className="min-h-screen p-6 md:p-10">
      <div className="max-w-6xl mx-auto flex flex-col md:flex-row gap-8">
        {/* Left Sidebar for Steps */}
        <div className="md:w-1/4 sticky top-10 h-fit space-y-4 p-4 rounded-xl glass shadow-lg">
          <h2 className="text-lg font-headline font-semibold text-on-surface mb-4">
            Staking Progress
          </h2>
          <div className="space-y-3">
            {/* Step 1 Indicator */}
            <div className="flex items-center gap-3">
              <div
                className={`w-8 h-8 flex items-center justify-center rounded-full font-bold text-sm ${isOwnedByEscrow ? 'bg-success/15 text-success border border-success/30' : 'bg-white/5 text-on-surface-variant border border-white/10'}`}
              >
                1
              </div>
              <div>
                <p
                  className={`font-medium ${isOwnedByEscrow ? 'text-on-surface' : 'text-on-surface-variant'}`}
                >
                  Transfer Ownership
                </p>
                <p
                  className={`text-xs ${isOwnedByEscrow ? 'text-success' : 'text-on-surface-variant/80'}`}
                >
                  {isOwnedByEscrow ? 'Completed' : 'Required'}
                </p>
              </div>
            </div>
            {/* Step 2 Indicator */}
            <div className="flex items-center gap-3">
              <div
                className={`w-8 h-8 flex items-center justify-center rounded-full font-bold text-sm ${isFactoryStaked ? 'bg-success/15 text-success border border-success/30' : 'bg-white/5 text-on-surface-variant border border-white/10'}`}
              >
                2
              </div>
              <div>
                <p
                  className={`font-medium ${isFactoryStaked ? 'text-on-surface' : 'text-on-surface-variant'}`}
                >
                  Stake / Unstake
                </p>
                <p
                  className={`text-xs ${isFactoryStaked ? 'text-success' : 'text-on-surface-variant/80'}`}
                >
                  {isFactoryStaked ? 'Staked' : 'Not Staked'}
                </p>
              </div>
            </div>
            {/* Add more steps as needed */}
          </div>
        </div>

        {/* Main Content Area */}
        <div className="md:w-3/4 space-y-8">
          <PageHeader
            title="Vesting Wallet Staking"
            description="Securely stake your vesting wallet in two transparent steps: transfer ownership, then stake."
            actions={
              <>
                <Button variant="secondary" onClick={() => router.back()}>
                  ← Back
                </Button>
                <Badge tone="info" size="md" className="uppercase tracking-wide">
                  {environment}
                </Badge>
              </>
            }
          />

          {!isConnected && (
            <EmptyState
              title="Connect your wallet"
              description="Connect your wallet to discover your vesting wallet and manage staking."
            />
          )}

          {!hasEscrow && (
            <EmptyState
              title="Vesting staking unavailable"
              description="Vesting staking is not available on this chain and environment."
            />
          )}

          {hasEscrow && noFactoriesConfigured && <EmptyState title="No factories configured" />}

          {hasMultipleVestingWallets && (
            <ErrorState
              title="Multiple vesting wallets detected"
              description="We detected multiple vesting wallets associated with this address. Please contact us on Discord so we can investigate why you have multiple vesting wallets."
            />
          )}

          {hasEscrow && !noFactoriesConfigured && isConnected && noVestingWalletFound && (
            <EmptyState
              title="No vesting wallet found"
              description="No vesting wallet associated with this address. Once a vesting wallet is created for you, it will appear here automatically."
            />
          )}

          {hasEscrow && factories.length > 0 && vestingWallet && (
            <div className="space-y-6">
              {/* Step 1: Transfer ownership */}
              <section className="glass rounded-3xl p-7 space-y-5 shadow-2xl">
                <div className="flex items-center justify-between gap-4 pb-4 border-b border-white/5">
                  <div>
                    <div className="text-sm uppercase tracking-wide text-info font-semibold">
                      Step 1
                    </div>
                    <h2 className="text-lg font-headline font-semibold text-on-surface mt-1">
                      Transfer Ownership to Escrow
                    </h2>
                  </div>
                  <Badge tone={isOwnedByEscrow ? 'success' : 'warning'} size="md">
                    {isOwnedByEscrow ? 'Completed' : 'Required'}
                  </Badge>
                </div>

                <div className="grid gap-5 text-base text-on-surface-variant md:grid-cols-2">
                  <div className="space-y-1">
                    <div className="text-xs text-on-surface-variant uppercase tracking-wide">
                      Vesting wallet
                    </div>
                    <div className="bg-surface-container border border-white/10 p-2 rounded-lg">
                      <AddressDisplay value={vestingWallet} full className="text-info text-sm" />
                    </div>
                  </div>
                  <div className="space-y-1">
                    <div className="text-xs text-on-surface-variant uppercase tracking-wide">
                      Escrow
                    </div>
                    <div className="bg-surface-container border border-white/10 p-2 rounded-lg">
                      <AddressDisplay value={escrowAddress} full className="text-info text-sm" />
                    </div>
                  </div>
                  <div className="space-y-1">
                    <div className="text-xs text-on-surface-variant uppercase tracking-wide">
                      Current owner
                    </div>
                    <div
                      className={`font-semibold ${isOwnedByEscrow ? 'text-success' : 'text-warning'}`}
                    >
                      {isOwnedByEscrow ? 'Escrow' : `You (${formatAddress(address)})`}
                    </div>
                  </div>
                  <div className="space-y-1">
                    <div className="text-xs text-on-surface-variant uppercase tracking-wide">
                      Vesting wallet SUMMER balance
                    </div>
                    <div className="text-on-surface text-lg font-bold tabular-nums">
                      {hasSummer
                        ? `${formattedSummerVestingBalance} ${summerSymbol || 'SUMMER'}`
                        : '—'}
                    </div>
                    <div className="text-xs text-on-surface-variant/80 mt-1">
                      This is the total SUMMER held by your vesting wallet - it represents the
                      amount of stSUMR you will get after staking.
                    </div>
                  </div>
                </div>

                <button
                  onClick={handleTransferOwnership}
                  disabled={!canTransferOwnership}
                  className={`mt-4 w-full md:w-auto inline-flex items-center justify-center px-6 py-3 rounded-xl text-lg font-bold shadow-lg transition-all duration-300 ease-in-out
                  ${
                    canTransferOwnership
                      ? 'bg-primary hover:bg-primary-dim text-on-primary transform hover:-translate-y-0.5'
                      : 'bg-white/10 text-on-surface-variant cursor-not-allowed'
                  }`}
                >
                  {currentAction === 'transfer' && isBusy
                    ? 'Transferring ownership...'
                    : 'Transfer Ownership to Escrow'}
                </button>

                <p className="text-sm text-on-surface-variant pt-2 border-t border-white/5 mt-4">
                  The escrow must own your vesting wallet before it can be staked. This does not
                  move your tokens; it only changes who controls the vesting contract.
                </p>
              </section>

              {/* Step 2: Stake / Unstake */}
              <section className="glass relative rounded-3xl p-7 space-y-5 shadow-2xl">
                {/* Note: z-10 kept as-is (not remapped to a z-index token) so the disabled
                   overlay's stacking relative to this section's siblings is unchanged. */}
                {step2Disabled && (
                  <div className="absolute inset-0 z-10 flex flex-col items-center justify-center rounded-2xl bg-surface/80 text-center px-6 backdrop-blur-sm">
                    <div className="text-lg font-bold text-on-surface">
                      Complete Step 1 to Continue
                    </div>
                    <div className="mt-2 text-sm text-on-surface-variant max-w-sm">
                      Once the escrow owns your vesting wallet, you&apos;ll be able to stake and
                      unstake it here.
                    </div>
                  </div>
                )}

                <div className={step2Disabled ? 'opacity-40 pointer-events-none select-none' : ''}>
                  <div className="flex items-center justify-between gap-4 pb-4 border-b border-white/5">
                    <div>
                      <div className="text-sm uppercase tracking-wide text-info font-semibold">
                        Step 2
                      </div>
                      <h2 className="text-lg font-headline font-semibold text-on-surface mt-1">
                        Stake / Unstake
                      </h2>
                      <p className="text-sm text-on-surface-variant mt-1">
                        Stake your vesting wallet into escrow and manage your staked position.
                      </p>
                    </div>
                    <Badge tone={isFactoryStaked ? 'success' : 'neutral'} size="md">
                      {isFactoryStaked ? 'Staked' : 'Not staked'}
                    </Badge>
                  </div>

                  <div className="mt-5 grid gap-5 md:grid-cols-2 text-base">
                    <div className="space-y-2">
                      <div className="text-xs text-on-surface-variant uppercase tracking-wide">
                        Factory
                      </div>
                      <div className="bg-surface-container border border-white/10 p-2 rounded-lg">
                        <AddressDisplay
                          value={factoryForWallet}
                          full
                          className="text-info text-sm"
                        />
                      </div>
                      <div className="text-xs text-on-surface-variant mt-4 uppercase tracking-wide">
                        Staked token
                      </div>
                      <div className="text-on-surface">
                        {hasXSummer ? (
                          <>
                            <span className="font-bold text-lg">{stakedTokenSymbol}</span>{' '}
                            <span className="font-mono text-info text-sm">
                              ({formatAddress(xSummerAddress)})
                            </span>
                          </>
                        ) : (
                          'xSUMR not configured for this chain'
                        )}
                      </div>
                    </div>

                    <div className="space-y-2">
                      <div className="text-xs text-on-surface-variant uppercase tracking-wide">
                        Your staked token balance
                      </div>
                      <div className="text-4xl font-extrabold text-on-surface tabular-nums">
                        {hasXSummer && isConnected ? (
                          <>
                            {formattedStakedBalance}{' '}
                            <span className="text-xl text-on-surface-variant font-semibold">
                              {stakedTokenSymbol}
                            </span>
                          </>
                        ) : (
                          '—'
                        )}
                      </div>
                      <div className="text-xs text-on-surface-variant mt-1">
                        This is the balance of all of your staked tokens. It includes both your
                        original staked tokens and ones received for vesting wallet staking.
                      </div>
                    </div>
                  </div>

                  <div className="mt-6 flex flex-wrap gap-4 pt-4 border-t border-white/5">
                    {!isFactoryStaked && (
                      <button
                        onClick={handleStake}
                        disabled={!canStake}
                        className={`inline-flex items-center justify-center px-6 py-3 rounded-xl text-lg font-bold shadow-lg transition-all duration-300 ease-in-out
                        ${
                          canStake
                            ? 'bg-primary hover:bg-primary-dim text-on-primary transform hover:-translate-y-0.5'
                            : 'bg-white/10 text-on-surface-variant cursor-not-allowed'
                        }`}
                      >
                        {currentAction === 'stake' && isBusy
                          ? 'Staking vesting wallet...'
                          : 'Stake'}
                      </button>
                    )}

                    {isFactoryStaked && hasXSummer && (
                      <>
                        <button
                          onClick={handleApproveXSummer}
                          disabled={!canApproveXSummer}
                          className={`inline-flex items-center justify-center px-6 py-3 rounded-xl text-lg font-bold shadow-lg transition-all duration-300 ease-in-out
                          ${
                            canApproveXSummer
                              ? 'bg-primary hover:bg-primary-dim text-on-primary transform hover:-translate-y-0.5'
                              : 'bg-white/10 text-on-surface-variant cursor-not-allowed'
                          }`}
                        >
                          {currentAction === 'approve' && isBusy
                            ? 'Approving xSUMR...'
                            : 'Approve xSUMR'}
                        </button>
                        <button
                          onClick={handleUnstake}
                          disabled={!canUnstake}
                          className={`inline-flex items-center justify-center px-6 py-3 rounded-xl text-lg font-bold shadow-lg transition-all duration-300 ease-in-out
                          ${
                            canUnstake
                              ? 'bg-error/15 border border-error/30 text-error hover:bg-error/25 transform hover:-translate-y-0.5'
                              : 'bg-white/10 text-on-surface-variant cursor-not-allowed'
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
                    <p className="mt-3 text-sm text-warning bg-warning/10 border border-warning/30 rounded-lg p-3">
                      <span className="font-bold">Important:</span> To unstake, escrow needs
                      permission to burn your staked tokens. Please approve xSUMR first, then you
                      can unstake.
                    </p>
                  )}
                </div>
              </section>
            </div>
          )}
        </div>
      </div>
    </main>
  )
}
