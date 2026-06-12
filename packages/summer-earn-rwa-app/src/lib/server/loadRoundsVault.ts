import { cacheLife, cacheTag } from 'next/cache'

import 'server-only'

import type { AppEnvironment } from '@/config/appEnvironment'
import { gqlFetch } from '@/lib/subgraph/client'
import { ROUNDS_VAULT_WITH_RECENT_ROUNDS } from '@/lib/subgraph/queries/rounds'
import type { SubgraphRoundsVault } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'

export async function loadRoundsVault(
  env: AppEnvironment,
  chainId: ChainId,
  roundsVaultAddress: string,
): Promise<SubgraphRoundsVault | null> {
  'use cache'
  cacheLife({ stale: 15, revalidate: 30, expire: 300 })
  cacheTag(`rounds-vault:${env}:${chainId}:${roundsVaultAddress.toLowerCase()}`)

  try {
    const data = await gqlFetch<{ roundsVault: SubgraphRoundsVault | null }>(
      chainId,
      env,
      ROUNDS_VAULT_WITH_RECENT_ROUNDS,
      { id: roundsVaultAddress.toLowerCase(), first: 30 },
    )
    return data.roundsVault
  } catch {
    return null
  }
}
