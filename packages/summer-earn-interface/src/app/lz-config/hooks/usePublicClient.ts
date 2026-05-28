'use client'
import { useMemo } from 'react'
import { createPublicClient, type PublicClient } from 'viem'

import { CHAIN_RPC_URLS, createRpcTransport,VIEM_CHAIN_ENTITIES } from '../../../config/chains'
import { CHAIN_NAME_TO_ID, ChainName } from '../lib/types'

export function makePublicClient(chain: ChainName): PublicClient | null {
  const chainId = CHAIN_NAME_TO_ID[chain]
  const viemChain = VIEM_CHAIN_ENTITIES[chainId]
  const urls = CHAIN_RPC_URLS[chainId]
  if (!viemChain || !urls || urls.length === 0) return null
  return createPublicClient({
    chain: viemChain,
    transport: createRpcTransport(urls),
  }) as PublicClient
}

export function useLzPublicClient(chain: ChainName): PublicClient | null {
  return useMemo(() => makePublicClient(chain), [chain])
}
