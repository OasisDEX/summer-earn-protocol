import { type BatchOptions, Eip1193Executor, Presets, type StepExecutor } from '@halaprix/domino'
import { createPublicClient } from 'viem'

import { CHAIN_RPC_URLS, createRpcTransport, VIEM_CHAIN_ENTITIES } from '@/config/chains'

/**
 * Single tuning point for every domino run in this app.
 * NOTE: adaptiveBatching retries can amplify RPC 429s (up to 2N-1 extra calls
 * per failing batch) — if rate-limit errors show up in logs, drop it here.
 */
export const DEFAULT_RUN_OPTIONS: BatchOptions = { ...Presets.throughput }

export function createExecutorForChain(chainId: string): StepExecutor {
  const rpcUrls = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
  const chain = VIEM_CHAIN_ENTITIES[chainId as keyof typeof VIEM_CHAIN_ENTITIES]
  if (!rpcUrls || !chain) {
    throw new Error(`No RPC configuration for chain ${chainId}`)
  }
  const client = createPublicClient({ transport: createRpcTransport(rpcUrls), chain })
  // viem PublicClient satisfies Eip1193Provider via its .request method.
  // Eip1193Executor falls back to deployless Multicall3 on chains missing
  // from its deployment table (e.g. HyperEVM), so no manual multicall3
  // chain-entity injection is needed.
  return new Eip1193Executor(client as any)
}
