import type { Chain, Transport } from 'viem'
import { fallback, http } from 'viem'
import { arbitrum, base, hyperliquid, mainnet, sonic } from 'wagmi/chains'

import { getInstitutionsV2SubgraphUrlOverride } from '@/config/env'
import type { ChainId } from '@/types/chain'

export const CHAIN_NAMES: Record<ChainId, string> = {
  [base.id]: 'Base',
  [mainnet.id]: 'Ethereum',
  [arbitrum.id]: 'Arbitrum',
  [sonic.id]: 'Sonic',
  [hyperliquid.id]: 'Hyperliquid',
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
  [mainnet.id]: [
    'https://rpc.mevblocker.io/noreverts',
    'https://eth.llamarpc.com',
    'https://ethereum-rpc.publicnode.com',
    'https://eth.rpc.blxrbdn.com',
    'https://eth-mainnet.public.blastapi.io',
    'https://ethereum.public.blockpi.network/v1/rpc/public',
    'https://eth.drpc.org',
    'https://1rpc.io/eth',
    'https://cloudflare-eth.com',
  ],
  [arbitrum.id]: [
    'https://arb1.arbitrum.io/rpc',
    'https://arbitrum-one-public.nodies.app',
    'https://arbitrum-one-rpc.publicnode.com',
    'https://arb1.lava.build',
    'https://arbitrum.gateway.tenderly.co',
    'https://arbitrum.drpc.org',
  ],
  [sonic.id]: [
    'https://rpc.soniclabs.com',
    'https://sonic.drpc.org',
    'https://sonic-rpc.publicnode.com',
  ],
  [hyperliquid.id]: [hyperliquid.rpcUrls.default.http[0] as string],
}

export const CHAIN_BLOCK_EXPLORERS: Record<ChainId, string> = {
  [base.id]: 'https://basescan.org',
  [mainnet.id]: 'https://etherscan.io',
  [arbitrum.id]: 'https://arbiscan.io',
  [sonic.id]: 'https://explorer.sonic.network',
  [hyperliquid.id]: hyperliquid.blockExplorers.default.url,
}

// Staging Goldsky proxy (Oasis app convention mirrored from
// summer-earn-interface's CHAIN_INSTITUTIONS_SUBGRAPH_URLS — same hostname,
// `-v2` slug suffix). Override per-chain via NEXT_PUBLIC_INSTITUTIONS_V2_SUBGRAPH_URL_*.
const DEFAULT_INSTITUTIONS_V2_URLS: Record<ChainId, string> = {
  [base.id]: 'https://subgraph.staging.oasisapp.dev/summer-institutions-v2-base',
  [mainnet.id]: 'https://subgraph.staging.oasisapp.dev/summer-institutions-v2',
  [arbitrum.id]: 'https://subgraph.staging.oasisapp.dev/summer-institutions-v2-arbitrum',
  [sonic.id]: 'https://subgraph.staging.oasisapp.dev/summer-institutions-v2-sonic',
  [hyperliquid.id]: 'https://subgraph.staging.oasisapp.dev/summer-institutions-v2-hyperliquid',
}

export function getInstitutionsV2SubgraphUrl(chainId: ChainId): string {
  return getInstitutionsV2SubgraphUrlOverride(chainId) ?? DEFAULT_INSTITUTIONS_V2_URLS[chainId]
}

export const VIEM_CHAIN_ENTITIES: Record<ChainId, Chain> = {
  [base.id]: base,
  [mainnet.id]: mainnet,
  [arbitrum.id]: arbitrum,
  [sonic.id]: sonic,
  [hyperliquid.id]: hyperliquid,
}

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
