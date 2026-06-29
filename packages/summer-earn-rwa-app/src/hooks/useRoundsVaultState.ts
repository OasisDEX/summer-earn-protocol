'use client'

import { useQuery } from '@tanstack/react-query'
import { useReadContracts } from 'wagmi'

import { roundsVaultInputAbi } from '@/abis/RoundsVaultInput'
import { chainRoundStateLabel } from '@/lib/rounds/roundState'
import type { ChainId } from '@/types/chain'

interface UseRoundsVaultStateProps {
  roundsVaultAddress: `0x${string}`
  chainId: ChainId
}

// Live read of the four fields the deposit/cancel/claim UI actually needs:
// currentRound (== _roundNumber), state of that round, minPositionSize, and
// the in-flight exchange rate (zero until settle). Uses RoundsVaultInput ABI
// — output's surface is identical for these reads.
export function useRoundsVaultState({ roundsVaultAddress, chainId }: UseRoundsVaultStateProps) {
  // Per-contract chainId — useReadContracts has no top-level chainId. Pins reads
  // to the institution's chain instead of the wallet's connected chain.
  const cid = Number(chainId)

  const reads = useReadContracts({
    contracts: [
      {
        address: roundsVaultAddress,
        abi: roundsVaultInputAbi,
        functionName: 'getCurrentRound',
        chainId: cid,
      },
      {
        address: roundsVaultAddress,
        abi: roundsVaultInputAbi,
        functionName: 'minPositionSize',
        chainId: cid,
      },
    ],
    query: {
      refetchInterval: 6_000,
    },
  })

  const currentRound = reads.data?.[0]?.result as bigint | undefined
  const minPositionSize = reads.data?.[1]?.result as bigint | undefined

  // Second-stage read: state + exchangeRate for the current round. Could be
  // bundled with the first multicall but the dependent arg means we'd need
  // an extra round trip anyway when currentRound updates.
  const dependent = useQuery({
    queryKey: ['rounds-vault-current', chainId, roundsVaultAddress, currentRound?.toString()],
    enabled: currentRound !== undefined,
    queryFn: async () => ({ raw: 0 }),
  })

  const stateReads = useReadContracts({
    contracts:
      currentRound !== undefined
        ? [
            {
              address: roundsVaultAddress,
              abi: roundsVaultInputAbi,
              functionName: 'roundState',
              args: [currentRound],
              chainId: cid,
            },
            {
              address: roundsVaultAddress,
              abi: roundsVaultInputAbi,
              functionName: 'getExchangeRate',
              args: [currentRound],
              chainId: cid,
            },
            {
              address: roundsVaultAddress,
              abi: roundsVaultInputAbi,
              functionName: 'totalSupply',
              args: [currentRound],
              chainId: cid,
            },
          ]
        : [],
    query: {
      enabled: currentRound !== undefined,
      refetchInterval: 6_000,
    },
  })

  const roundStateRaw = stateReads.data?.[0]?.result as number | undefined
  const exchangeRate = stateReads.data?.[1]?.result as
    | { baseAmount: bigint; quoteAmount: bigint }
    | undefined
  const currentRoundSupply = stateReads.data?.[2]?.result as bigint | undefined

  return {
    currentRound,
    minPositionSize,
    roundState: roundStateRaw === undefined ? undefined : chainRoundStateLabel(roundStateRaw),
    exchangeRate,
    currentRoundSupply,
    loading: reads.isLoading || (currentRound !== undefined && stateReads.isLoading),
    error: (reads.error ?? stateReads.error ?? dependent.error) as Error | null,
    refetch: () => Promise.all([reads.refetch(), stateReads.refetch()]),
  }
}
