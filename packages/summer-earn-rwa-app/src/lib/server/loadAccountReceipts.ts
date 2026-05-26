import { unstable_cacheLife as cacheLife, unstable_cacheTag as cacheTag } from 'next/cache'

import 'server-only'

import { gqlFetch } from '@/lib/subgraph/client'
import { ACCOUNT_RECEIPTS } from '@/lib/subgraph/queries/receipts'
import type { SubgraphReceipt } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'

interface AccountResponse {
  account: { id: string; roundsVaultReceipts: SubgraphReceipt[] } | null
}

export async function loadAccountReceipts(
  chainId: ChainId,
  account: string,
): Promise<SubgraphReceipt[]> {
  'use cache'
  cacheLife({ stale: 10, revalidate: 30, expire: 300 })
  cacheTag(`account:${chainId}:${account.toLowerCase()}`)

  try {
    const data = await gqlFetch<AccountResponse>(chainId, ACCOUNT_RECEIPTS, {
      account: account.toLowerCase(),
    })
    return data.account?.roundsVaultReceipts ?? []
  } catch {
    return []
  }
}
