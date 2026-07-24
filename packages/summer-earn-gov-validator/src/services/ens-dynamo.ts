import { getCache, putCache } from '@/lib/dynamodb'

import { resolveEnsNames } from './ens'

// ENS reverse records rarely change, so cache them per-address in DynamoDB for a
// week. Negative results (no ENS) are cached too — most voter addresses have no
// name, and re-resolving them on every cold render is the expensive case. DynamoDB
// errors degrade to a plain RPC resolve, never to a failed render.

const ENS_TTL_SECONDS = 7 * 24 * 60 * 60

interface EnsCacheItem {
  data: { name: string }
  updatedAt?: string
}

export async function resolveEnsNamesDynamoCached(
  addresses: string[],
): Promise<Record<string, string>> {
  const unique = Array.from(new Set(addresses.map((a) => a.toLowerCase())))
  if (unique.length === 0) return {}

  const items = await Promise.all(unique.map((addr) => getCache<EnsCacheItem>('ens', addr)))

  const result: Record<string, string> = {}
  const missing: string[] = []
  unique.forEach((addr, i) => {
    const item = items[i]
    const ageSeconds = item?.updatedAt
      ? (Date.now() - new Date(item.updatedAt).getTime()) / 1000
      : Infinity
    if (item && ageSeconds < ENS_TTL_SECONDS) {
      if (item.data?.name) result[addr] = item.data.name
    } else {
      missing.push(addr)
    }
  })

  if (missing.length > 0) {
    const resolved = await resolveEnsNames(missing)
    // Best-effort writes; include empty names so known-nameless addresses hit cache.
    await Promise.allSettled(
      missing.map((addr) => putCache('ens', addr, { data: { name: resolved[addr] || '' } })),
    )
    for (const addr of missing) {
      if (resolved[addr]) result[addr] = resolved[addr]
    }
  }

  return result
}
