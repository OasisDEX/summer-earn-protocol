'use client'

import { useQuery } from '@tanstack/react-query'
import type { Address } from 'viem'
import { usePublicClient } from 'wagmi'

import { fleetCommanderAbi } from '@/abis/FleetCommander'
import type { ChainId } from '@/types/chain'

export interface SourceVaultPreview {
  /** convertToShares(assets) — used to set tradeAmount when user types underlying amount. */
  shares: bigint
  /** convertToAssets(shares) — used to display history amounts (subgraph stores shares). */
  assetsFromShares: bigint
}

interface UseSourceVaultPreviewInput {
  chainId: ChainId
  sourceVault?: Address
  /** Underlying asset amount the user typed. */
  assets?: bigint
  /** Share amount the user typed (mirrored field). */
  shares?: bigint
}

// Two-way conversion against the FleetCommander vault. When the user types
// the underlying amount we read convertToShares; when they type shares we
// read convertToAssets. Either side is the source of truth for that render.
export function useSourceVaultPreview(input: UseSourceVaultPreviewInput) {
  const client = usePublicClient({ chainId: Number(input.chainId) })
  const enabled =
    Boolean(input.sourceVault) &&
    Boolean(client) &&
    ((input.assets !== undefined && input.assets > 0n) ||
      (input.shares !== undefined && input.shares > 0n))

  return useQuery({
    queryKey: [
      'dca',
      'preview',
      input.chainId,
      input.sourceVault?.toLowerCase(),
      input.assets?.toString(),
      input.shares?.toString(),
    ],
    enabled,
    staleTime: 30_000,
    queryFn: async (): Promise<SourceVaultPreview> => {
      if (!client || !input.sourceVault) throw new Error('not ready')
      const assetsIn = input.assets ?? 0n
      const sharesIn = input.shares ?? 0n
      const calls = [
        {
          address: input.sourceVault,
          abi: fleetCommanderAbi,
          functionName: 'convertToShares' as const,
          args: [assetsIn] as const,
        },
        {
          address: input.sourceVault,
          abi: fleetCommanderAbi,
          functionName: 'convertToAssets' as const,
          args: [sharesIn] as const,
        },
      ]
      const result = await client.multicall({ contracts: calls, allowFailure: false })
      return {
        shares: result[0] as bigint,
        assetsFromShares: result[1] as bigint,
      }
    },
  })
}
