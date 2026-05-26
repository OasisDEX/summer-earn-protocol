import { cacheLife, cacheTag } from 'next/cache'

import 'server-only'

import {
  getInstitutionBySlug,
  type Institution,
  type InstitutionFleet,
} from '@/config/institutions'
import { gqlFetch } from '@/lib/subgraph/client'
import { FLEET_DETAIL } from '@/lib/subgraph/queries/fleets'
import type { SubgraphVault } from '@/lib/subgraph/types'

export interface LoadedInstitutionFleet extends InstitutionFleet {
  vault: SubgraphVault | null
}

export interface LoadedInstitution extends Omit<Institution, 'fleets'> {
  fleets: LoadedInstitutionFleet[]
}

interface VaultResponse {
  vault: SubgraphVault | null
}

export async function loadInstitution(slug: string): Promise<LoadedInstitution | null> {
  'use cache'
  cacheLife({ stale: 30, revalidate: 60, expire: 300 })
  cacheTag(`institution:${slug}`)

  const institution = getInstitutionBySlug(slug)
  if (!institution) return null

  const enriched: LoadedInstitutionFleet[] = await Promise.all(
    institution.fleets.map(async (fleet) => {
      try {
        const data = await gqlFetch<VaultResponse>(institution.chainId, FLEET_DETAIL, {
          id: fleet.fleetCommander.toLowerCase(),
        })
        return { ...fleet, vault: data.vault ?? null }
      } catch {
        return { ...fleet, vault: null }
      }
    }),
  )

  return { ...institution, fleets: enriched }
}
