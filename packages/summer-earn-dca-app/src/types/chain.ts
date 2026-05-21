// Currently DCA is deployed to Base only. Structured as a string union so it
// can index Record<ChainId, ...> maps the same way summer-earn-interface does.

export type ChainId = '8453'

export const SUPPORTED_CHAIN_IDS: readonly ChainId[] = ['8453'] as const

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
