'use client'

import { useQuery } from '@tanstack/react-query'
import type { Address } from 'viem'
import { usePublicClient } from 'wagmi'

import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { time } from '@/lib/perf'
import type { ChainId } from '@/types/chain'

export interface SourceVaultPreview {
  shares: bigint
  assetsFromShares: bigint
}

interface UseSourceVaultPreviewInput {
  chainId: ChainId
  sourceVault?: Address
  assets?: bigint
  shares?: bigint
  initialData?: SourceVaultPreview | null
}

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
    initialData: input.initialData ?? undefined,
    queryFn: async (): Promise<SourceVaultPreview> => {
      if (!client || !input.sourceVault) throw new Error('not ready')
      const assetsIn = input.assets ?? 0n
      const sharesIn = input.shares ?? 0n
      return time(`rpc:vault-preview ${input.sourceVault.slice(0, 6)}…`, async () => {
        const calls = [
          {
            address: input.sourceVault!,
            abi: fleetCommanderAbi,
            functionName: 'convertToShares' as const,
            args: [assetsIn] as const,
          },
          {
            address: input.sourceVault!,
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
      })
    },
  })
}
