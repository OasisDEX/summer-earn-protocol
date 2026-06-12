import { cacheLife, cacheTag } from 'next/cache'

import 'server-only'

import type { AppEnvironment } from '@/config/appEnvironment'
import { gqlFetch } from '@/lib/subgraph/client'
import { FLEET_DETAIL } from '@/lib/subgraph/queries/fleets'
import { REBALANCES_FOR_FLEET } from '@/lib/subgraph/queries/rebalances'
import { ROLES_FOR_FLEET } from '@/lib/subgraph/queries/roles'
import type { SubgraphRebalance, SubgraphRole, SubgraphVault } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'

export interface LoadedFleet {
  vault: SubgraphVault | null
  rebalances: SubgraphRebalance[]
  roles: SubgraphRole[]
}

export async function loadFleet(
  env: AppEnvironment,
  chainId: ChainId,
  fleetAddress: string,
): Promise<LoadedFleet> {
  'use cache'
  cacheLife({ stale: 30, revalidate: 60, expire: 300 })
  cacheTag(`fleet:${env}:${chainId}:${fleetAddress.toLowerCase()}`)

  const addr = fleetAddress.toLowerCase()

  const [vaultRes, rebalancesRes, rolesRes] = await Promise.all([
    gqlFetch<{ vault: SubgraphVault | null }>(chainId, env, FLEET_DETAIL, { id: addr }).catch(
      () => ({
        vault: null,
      }),
    ),
    gqlFetch<{ rebalances: SubgraphRebalance[] }>(chainId, env, REBALANCES_FOR_FLEET, {
      fleet: addr,
      first: 25,
    }).catch(() => ({ rebalances: [] })),
    gqlFetch<{ roles: SubgraphRole[] }>(chainId, env, ROLES_FOR_FLEET, { fleet: addr }).catch(
      () => ({
        roles: [],
      }),
    ),
  ])

  return {
    vault: vaultRes.vault,
    rebalances: rebalancesRes.rebalances,
    roles: rolesRes.roles,
  }
}
