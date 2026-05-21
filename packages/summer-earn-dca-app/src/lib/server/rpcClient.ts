import { createPublicClient, type PublicClient } from 'viem'

import 'server-only'

import { CHAIN_RPC_URLS, createRpcTransport, VIEM_CHAIN_ENTITIES } from '@/config/chains'
import type { ChainId } from '@/types/chain'

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
