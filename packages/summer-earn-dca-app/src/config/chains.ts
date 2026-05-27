import type { Chain, Transport } from 'viem'
import { fallback, http } from 'viem'
import { base } from 'wagmi/chains'

import type { ChainId } from '@/types/chain'

export const CHAIN_NAMES: Record<ChainId, string> = {
  [base.id]: 'Base',
}

export const CHAIN_RPC_URLS: Record<ChainId, string[]> = {
  [base.id]: [
    'https://base.lava.build',
    'https://base-public.nodies.app',
    'https://base-mainnet.public.blastapi.io',
    'https://base-rpc.publicnode.com',
    'https://base.public.blockpi.network/v1/rpc/public',
    'https://1rpc.io/base',
    'https://base.meowrpc.com',
    'https://base.gateway.tenderly.co',
    'https://gateway.tenderly.co/public/base',
    'https://base.drpc.org',
    'https://base.llamarpc.com',
    'https://mainnet.base.org',
  ],
}

export const CHAIN_BLOCK_EXPLORERS: Record<ChainId, string> = {
  [base.id]: 'https://basescan.org',
}

// Goldsky `summer-dca-base` subgraph fronted by the staging proxy — same
// convention as summer-earn-interface (e.g. summer-earn-protocol-rates-base).
export const CHAIN_DCA_SUBGRAPH_URLS: Record<ChainId, string> = {
  [base.id]: 'https://subgraph.staging.oasisapp.dev/summer-dca-base',
}

export const VIEM_CHAIN_ENTITIES: Record<ChainId, Chain> = {
  [base.id]: base,
}

// Mirror of summer-earn-interface's createRpcTransport — wraps each URL in
// viem's http() and uses fallback() so the wagmi client retries the next RPC
// when one fails. Keeps the behaviour identical across apps.
export function createRpcTransport(rpcUrls: string[]): Transport {
  if (rpcUrls.length === 0) {
    throw new Error('At least one RPC URL is required')
  }
  if (rpcUrls.length === 1) {
    return http(rpcUrls[0])
  }
  return fallback(
    rpcUrls.map((url) => http(url, { retryCount: 1, retryDelay: 200 })),
    { rank: false },
  )
}
