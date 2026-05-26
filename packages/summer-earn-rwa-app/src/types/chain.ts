// Multi-chain plumbing from day one (only Base has rounds-vault data today
// per ExtDemoCorp_v2, but other v2-institutions subgraph deploys exist).

export type ChainId = '8453' | '1' | '42161' | '146' | '999'

export const SUPPORTED_CHAIN_IDS: readonly ChainId[] = ['8453', '1', '42161', '146', '999'] as const

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
