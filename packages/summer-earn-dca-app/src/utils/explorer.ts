import { CHAIN_BLOCK_EXPLORERS } from '@/config/chains'
import type { ChainId } from '@/types/chain'

export function txExplorerUrl(chainId: ChainId, hash: `0x${string}`): string {
  return `${CHAIN_BLOCK_EXPLORERS[chainId]}/tx/${hash}`
}

export function addressExplorerUrl(chainId: ChainId, address: `0x${string}`): string {
  return `${CHAIN_BLOCK_EXPLORERS[chainId]}/address/${address}`
}

export function openTx(chainId: ChainId, hash?: `0x${string}`) {
  if (!hash) return
  window.open(txExplorerUrl(chainId, hash), '_blank', 'noopener,noreferrer')
}
