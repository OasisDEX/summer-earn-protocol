'use client'

import { useQuery } from '@tanstack/react-query'
import { useAccount } from 'wagmi'

import { gqlFetch } from '@/lib/subgraph/client'
import { ACCOUNT_RECEIPTS } from '@/lib/subgraph/queries/receipts'
import type { SubgraphReceipt } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'

interface AccountResponse {
  account: { id: string; roundsVaultReceipts: SubgraphReceipt[] } | null
}

interface UseUserReceiptsProps {
  chainId: ChainId
  /** Optional filter — return only receipts for this specific rounds-vault. */
  roundsVaultAddress?: `0x${string}`
  /** Optional override account; defaults to connected wallet. */
  owner?: `0x${string}`
}

export function useUserReceipts({ chainId, roundsVaultAddress, owner }: UseUserReceiptsProps) {
  const { address } = useAccount()
  const account = (owner ?? address)?.toLowerCase()

  // No initialData — the wallet address resolves only on the client, so the
  // server has nothing to seed. Passing `initialData: []` would tell React
  // Query the query has already succeeded, which suppresses the initial
  // fetch until staleTime/refetchInterval fires (visible as a ~20s wait
  // before any data appears).
  const query = useQuery({
    queryKey: ['user-receipts', chainId, account, roundsVaultAddress],
    enabled: !!account,
    queryFn: async () => {
      if (!account) return [] as SubgraphReceipt[]
      const data = await gqlFetch<AccountResponse>(chainId, ACCOUNT_RECEIPTS, { account })
      const rows = data.account?.roundsVaultReceipts ?? []
      if (!roundsVaultAddress) return rows
      const v = roundsVaultAddress.toLowerCase()
      return rows.filter((r) => r.vault.id.toLowerCase() === v)
    },
    staleTime: 15_000,
    refetchInterval: 20_000,
  })

  return {
    receipts: query.data ?? [],
    loading: query.isLoading,
    error: query.error as Error | null,
    refetch: query.refetch,
  }
}
