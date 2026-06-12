// All NEXT_PUBLIC_* env reads are funnelled through this module so the
// surface is small and grep-able.

import type { ChainId } from '@/types/chain'

export function getWalletConnectProjectId(): string {
  return process.env.NEXT_PUBLIC_WALLETCONNECT_ID || 'demo'
}

// Per-chain override for the PRODUCTION institutions-v2 subgraph url. The
// staging environment ignores these and uses the built-in `-staging` slugs.
const INSTITUTIONS_V2_ENV_BY_CHAIN: Record<ChainId, string> = {
  '8453': 'NEXT_PUBLIC_INSTITUTIONS_V2_SUBGRAPH_URL_BASE',
  '1': 'NEXT_PUBLIC_INSTITUTIONS_V2_SUBGRAPH_URL_MAINNET',
  '42161': 'NEXT_PUBLIC_INSTITUTIONS_V2_SUBGRAPH_URL_ARBITRUM',
  '146': 'NEXT_PUBLIC_INSTITUTIONS_V2_SUBGRAPH_URL_SONIC',
  '999': 'NEXT_PUBLIC_INSTITUTIONS_V2_SUBGRAPH_URL_HYPERLIQUID',
}

export function getInstitutionsV2SubgraphUrlOverride(chainId: ChainId): string | undefined {
  const envKey = INSTITUTIONS_V2_ENV_BY_CHAIN[chainId]
  const value = process.env[envKey]
  return value && value.length > 0 ? value : undefined
}
