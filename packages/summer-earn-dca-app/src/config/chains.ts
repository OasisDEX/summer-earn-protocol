import type { Chain, Transport } from 'viem'
import { fallback, http } from 'viem'
import { base } from 'wagmi/chains'

import type { ChainId } from '@/types/chain'

export const CHAIN_NAMES: Record<ChainId, string> = {
  [base.id]: 'Base',
}

// Public RPC fallback list for Base. Pulled from packages/summer-earn-interface/src/config/chains.ts.
// Override via NEXT_PUBLIC_BASE_RPC_URL (prepended to the head of the fallback list).
const BASE_RPC_URLS: string[] = [
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
]

function resolveBaseRpcUrls(): string[] {
  const override = process.env.NEXT_PUBLIC_BASE_RPC_URL
  return override ? [override, ...BASE_RPC_URLS] : BASE_RPC_URLS
}

export const CHAIN_RPC_URLS: Record<ChainId, string[]> = {
  [base.id]: resolveBaseRpcUrls(),
}

export const CHAIN_BLOCK_EXPLORERS: Record<ChainId, string> = {
  [base.id]: 'https://basescan.org',
}

// Goldsky DCA subgraph URLs — paste your deployed endpoint via env.
// The repo convention is `https://api.goldsky.com/api/public/<project>/subgraphs/summer-dca-base/<version>/gn`.
export const CHAIN_DCA_SUBGRAPH_URLS: Record<ChainId, string> = {
  [base.id]: process.env.NEXT_PUBLIC_DCA_SUBGRAPH_URL_BASE ?? '',
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
