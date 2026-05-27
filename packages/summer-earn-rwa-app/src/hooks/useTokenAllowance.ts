'use client'

import { useReadContracts } from 'wagmi'

import { erc20Abi } from '@/abis/ERC20'
import type { ChainId } from '@/types/chain'

interface UseTokenAllowanceProps {
  token: `0x${string}`
  owner?: `0x${string}`
  spender: `0x${string}`
  /** Retained for symmetry with other hooks; wagmi uses the connected chain. */
  chainId?: ChainId
}

// Combined balance + allowance + decimals + symbol read for a single token,
// scoped to a specific spender. Used by the deposit and withdraw forms which
// need allowance to the rounds-vault (not to the fleet).
export function useTokenAllowance({ token, owner, spender }: UseTokenAllowanceProps) {
  const reads = useReadContracts({
    contracts: [
      { address: token, abi: erc20Abi, functionName: 'decimals' },
      { address: token, abi: erc20Abi, functionName: 'symbol' },
      ...(owner
        ? [
            { address: token, abi: erc20Abi, functionName: 'balanceOf', args: [owner] },
            { address: token, abi: erc20Abi, functionName: 'allowance', args: [owner, spender] },
          ]
        : []),
    ] as never,
    query: {
      enabled: !!token,
      staleTime: 10_000,
      refetchInterval: 12_000,
    },
  })

  const data = (reads.data ?? []) as Array<{ status: 'success' | 'failure'; result?: unknown }>
  const decimals = data[0]?.result as number | undefined
  const symbol = data[1]?.result as string | undefined
  const balance = owner ? (data[2]?.result as bigint | undefined) : undefined
  const allowance = owner ? (data[3]?.result as bigint | undefined) : undefined

  return {
    decimals,
    symbol,
    balance,
    allowance,
    loading: reads.isLoading,
    refetch: reads.refetch,
  }
}
