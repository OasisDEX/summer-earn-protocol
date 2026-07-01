// DCA is deployed to Base + Ethereum mainnet. Structured as a string union so
// it can index Record<ChainId, ...> maps the same way summer-earn-interface
// does. Chain is URL-encoded as a slug (route segment for /strategy,
// `?chain=` query param elsewhere) — see CHAIN_SLUGS below.

export type ChainId = '8453' | '1'

export const SUPPORTED_CHAIN_IDS: readonly ChainId[] = ['8453', '1'] as const

export const DEFAULT_CHAIN_ID: ChainId = '8453'

export function isSupportedChain(id: unknown): id is ChainId {
  return typeof id === 'string' && SUPPORTED_CHAIN_IDS.includes(id as ChainId)
}

export function asChainId(id: number | string): ChainId {
  const s = String(id) as ChainId
  if (!isSupportedChain(s)) {
    throw new Error(`Unsupported chain id: ${id}`)
  }
  return s
}

// URL slug per chain. `base` → 8453, `mainnet` → 1.
export const CHAIN_SLUGS: Record<ChainId, string> = {
  '8453': 'base',
  '1': 'mainnet',
}

export function chainSlug(id: ChainId): string {
  return CHAIN_SLUGS[id]
}

// Reverse lookup: slug → ChainId, or undefined when the slug is unknown.
export function chainIdFromSlug(slug: string | undefined): ChainId | undefined {
  if (!slug) return undefined
  for (const id of SUPPORTED_CHAIN_IDS) {
    if (CHAIN_SLUGS[id] === slug) return id
  }
  return undefined
}

// Resolve a raw URL slug to a ChainId, defaulting to Base when
// absent/invalid (so bare `/portfolio` still works).
export function resolveChainParam(raw: string | undefined): ChainId {
  return chainIdFromSlug(raw) ?? DEFAULT_CHAIN_ID
}
