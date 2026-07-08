const POOL_ADDRESS_RE = /^0x[a-fA-F0-9]{40}$/

export type ArkStatus = 'active' | 'ready-to-remove' | 'stuck-needs-sweep'

export interface ArkDetails {
  protocol?: string
  pool?: `0x${string}`
  chainId?: number
}

export function getArkStatus(ark: {
  isBufferArk: boolean
  depositCap: bigint
  totalAssets: bigint
}): ArkStatus {
  if (ark.isBufferArk) return 'active'
  if (ark.depositCap === 0n) {
    return ark.totalAssets === 0n ? 'ready-to-remove' : 'stuck-needs-sweep'
  }
  return 'active'
}

export function parseArkDetails(detailsJson: string | undefined): ArkDetails | null {
  if (!detailsJson) return null
  try {
    const parsed = JSON.parse(detailsJson) as Record<string, unknown>
    const pool =
      typeof parsed.pool === 'string' && POOL_ADDRESS_RE.test(parsed.pool)
        ? (parsed.pool as `0x${string}`)
        : undefined
    const protocol = typeof parsed.protocol === 'string' ? parsed.protocol : undefined
    const chainId = typeof parsed.chainId === 'number' ? parsed.chainId : undefined
    return { protocol, pool, chainId }
  } catch {
    return null
  }
}
