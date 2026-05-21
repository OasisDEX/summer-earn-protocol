import { createPublicClient, type PublicClient } from 'viem'

import 'server-only'

import { CHAIN_RPC_URLS, createRpcTransport, VIEM_CHAIN_ENTITIES } from '@/config/chains'
import type { ChainId } from '@/types/chain'

// Server-side viem client cache, keyed by chain. Created lazily so each
// Next.js server instance opens at most one connection pool per chain.
// Uses the same RPC fallback list as the wagmi client on the browser side.
const _clients = new Map<ChainId, PublicClient>()

export function getServerPublicClient(chainId: ChainId): PublicClient {
  const cached = _clients.get(chainId)
  if (cached) return cached
  const client = createPublicClient({
    chain: VIEM_CHAIN_ENTITIES[chainId],
    transport: createRpcTransport(CHAIN_RPC_URLS[chainId]),
  })
  _clients.set(chainId, client)
  return client
}
