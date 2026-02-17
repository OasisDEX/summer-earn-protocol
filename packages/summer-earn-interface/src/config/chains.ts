import { fallback, http, type Transport } from 'viem'
import { arbitrum, base, Chain, hyperliquid, mainnet, sonic } from 'viem/chains'

import { ChainId } from '../types'

export const CHAIN_NAMES: Record<ChainId, string> = {
  [mainnet.id]: 'Ethereum',
  [arbitrum.id]: 'Arbitrum',
  [base.id]: 'Base',
  [sonic.id]: 'Sonic',
  [hyperliquid.id]: 'Hyperliquid',
}

export const CHAIN_RPC_URLS: Record<ChainId, string[]> = {
  [mainnet.id]: [
    'https://rpc.mevblocker.io/noreverts', // Primary (MEV protection)
    'https://eth.llamarpc.com', // Fast fallback
    'https://ethereum-rpc.publicnode.com', // Public node
    'https://eth.rpc.blxrbdn.com', // Bloxroute
    'https://eth-mainnet.public.blastapi.io', // Blast API
    'https://ethereum.public.blockpi.network/v1/rpc/public', // BlockPI
    'https://ethereum-mainnet.gateway.tatum.io', // Tatum
    'https://0xrpc.io/eth', // 0xRPC
    'https://eth1.lava.build', // Lava Network
    'https://eth.api.pocket.network', // Pocket Network
    'https://rpc.eth.gateway.fm', // Gateway.fm
    'https://eth.meowrpc.com', // MeowRPC
    'https://ethereum-public.nodies.app', // Nodies
    'https://eth.api.onfinality.io/public', // OnFinality
    'https://ethereum.rpc.subquery.network/public', // SubQuery
    'https://eth.drpc.org', // dRPC
    'https://rpc.fullsend.to', // FullSend
    'https://rpc.mevblocker.io', // MEV Blocker (standard)
    'https://rpc.mevblocker.io/fast', // MEV Blocker (fast)
    'https://eth.merkle.io', // Merkle
    'https://1rpc.io/eth', // 1RPC
    'https://ethereum-json-rpc.stakely.io', // Stakely
    'https://cloudflare-eth.com', // Cloudflare
    'https://eth-mainnet-public.unifra.io', // Unifra
  ],
  [arbitrum.id]: [
    'https://arb1.arbitrum.io/rpc', // Primary (Arbitrum official)
    'https://arbitrum-one-public.nodies.app', // Fastest (0.232s)
    'https://arbitrum-one-rpc.publicnode.com', // Public node (0.233s)
    'https://arb1.lava.build', // Lava Network (0.234s)
    'https://public-arb-mainnet.fastnode.io', // FastNode (0.234s)
    'https://arbitrum-one.public.blastapi.io', // Blast API (0.235s)
    'https://arb-one-mainnet.gateway.tatum.io', // Tatum (0.235s)
    'https://arbitrum.gateway.tenderly.co', // Tenderly (0.237s)
    'https://arbitrum.rpc.subquery.network/public', // SubQuery (0.288s)
    'https://arbitrum.meowrpc.com', // MeowRPC (0.357s)
    'https://arb-one.api.pocket.network', // Pocket Network (0.356s)
    'https://api.zan.top/arb-one', // Zan (0.377s)
    'https://rpc.sentio.xyz/arbitrum-one', // Sentio (0.442s)
    'https://rpc.owlracle.info/arb/70d38ce1826c4a60bb2a8e05a6c8b20f', // Owlracle (0.593s)
    'https://1rpc.io/arb', // 1RPC (1.032s)
    'https://arbitrum.drpc.org', // dRPC (1.052s)
    'https://arbitrum.public.blockpi.network/v1/rpc/public', // BlockPI
    'https://rpc.arb1.arbitrum.gateway.fm', // Gateway.fm
    'https://arb-mainnet-public.unifra.io', // Unifra
    'https://public.stackup.sh/api/v1/node/arbitrum-one', // Stackup
    'https://endpoints.omniatech.io/v1/arbitrum/one/public', // Omniatech
    'https://arbitrum.api.onfinality.io/public', // OnFinality
    'https://arbitrum.therpc.io', // TheRPC
    'https://rpc.poolz.finance/arbitrum', // Poolz
  ],
  [base.id]: [
    'https://base.lava.build', // Primary (Lava Network)
    'https://base-public.nodies.app', // Fastest (0.089s)
    'https://base-mainnet.public.blastapi.io', // Blast API (0.090s)
    'https://base-rpc.publicnode.com', // Public node (0.089s)
    'https://base.public.blockpi.network/v1/rpc/public', // BlockPI (0.228s)
    'https://1rpc.io/base', // 1RPC (0.227s)
    'https://base.meowrpc.com', // MeowRPC (0.228s)
    'https://base.gateway.tenderly.co', // Tenderly (0.229s)
    'https://gateway.tenderly.co/public/base', // Tenderly public (0.246s)
    'https://base.drpc.org', // dRPC (0.247s)
    'https://base.llamarpc.com', // LlamaRPC (0.305s)
    'https://base.api.pocket.network', // Pocket Network (0.305s)
    'https://api-base-mainnet-archive.n.dwellir.com/2ccf18bf-2916-4198-8856-42172854353c', // Dwellir (0.306s)
    'https://mainnet.base.org', // Base official (0.443s)
    'https://base.rpc.blxrbdn.com', // Bloxroute (0.443s)
    'https://rpc.sentio.xyz/base', // Sentio (0.444s)
    'https://developer-access-mainnet.base.org', // Base developer (0.650s)
    'https://base.rpc.subquery.network/public', // SubQuery (0.501s)
    'https://api.zan.top/base-mainnet', // Zan (0.267s)
    'https://endpoints.omniatech.io/v1/base/mainnet/public', // Omniatech
    'https://public.stackup.sh/api/v1/node/base-mainnet', // Stackup
    'https://base-mainnet.gateway.tatum.io', // Tatum
  ],
  [sonic.id]: [
    'https://rpc.soniclabs.com', // Fastest (0.068s)
    'https://sonic.drpc.org', // 0.094s
    'https://sonic-json-rpc.stakely.io', // 0.110s
    'https://sonic-rpc.publicnode.com', // 0.119s
    'https://rpc.sentio.xyz/sonic-mainnet', // 0.222s
    'https://sonic.api.pocket.network', // 0.392s
    'https://api-sonic-mainnet-archive.n.dwellir.com/2ccf18bf-2916-4198-8856-42172854353c', // Dwellir
    'https://sonic.therpc.io', // TheRPC
    'https://sonic.api.onfinality.io/public', // OnFinality
    'https://rpc.ankr.com/sonic_mainnet', // Ankr
  ],
  [hyperliquid.id]: [hyperliquid.rpcUrls.default.http[0] as string],
}

export const CHAIN_BLOCK_EXPLORERS: Record<ChainId, string> = {
  [mainnet.id]: 'https://etherscan.io',
  [arbitrum.id]: 'https://arbiscan.io',
  [base.id]: 'https://basescan.org',
  [sonic.id]: 'https://explorer.sonic.network',
  [hyperliquid.id]: hyperliquid.blockExplorers.default.url,
}

export const CHAIN_SUBGRAPH_URLS: Record<ChainId, string> = {
  [mainnet.id]: 'https://subgraph.staging.oasisapp.dev/summer-earn-protocol-rates',
  [arbitrum.id]: 'https://subgraph.staging.oasisapp.dev/summer-earn-protocol-rates-arbitrum',
  [base.id]: 'https://subgraph.staging.oasisapp.dev/summer-earn-protocol-rates-base',
  [sonic.id]: 'https://subgraph.staging.oasisapp.dev/summer-earn-protocol-rates-sonic',
  [hyperliquid.id]: 'https://subgraph.staging.oasisapp.dev/summer-earn-protocol-rates-hyperliquid',
}

// Institutions subgraphs per chain (staging endpoints by default)
export const CHAIN_INSTITUTIONS_SUBGRAPH_URLS: Record<ChainId, string> = {
  [mainnet.id]: 'https://subgraph.staging.oasisapp.dev/summer-institutions',
  [arbitrum.id]: 'https://subgraph.staging.oasisapp.dev/summer-institutions-arbitrum',
  [base.id]: 'https://subgraph.staging.oasisapp.dev/summer-institutions-base',
  [sonic.id]: 'https://subgraph.staging.oasisapp.dev/summer-institutions-sonic',
  [hyperliquid.id]: 'https://subgraph.staging.oasisapp.dev/summer-institutions-hyperliquid',
}

export const CHAIN_PROTOCOL_SUBGRAPH_URLS: Record<ChainId, string> = {
  [mainnet.id]: 'https://subgraph.staging.oasisapp.dev/summer-protocol',
  [arbitrum.id]: 'https://subgraph.staging.oasisapp.dev/summer-protocol-arbitrum',
  [base.id]: 'https://subgraph.staging.oasisapp.dev/summer-protocol-base',
  [sonic.id]: 'https://subgraph.staging.oasisapp.dev/summer-protocol-sonic',
  [hyperliquid.id]: 'https://subgraph.staging.oasisapp.dev/summer-protocol-hyperliquid',
}

// Governance subgraphs per chain (staging endpoints by default)
export const CHAIN_GOVERNANCE_SUBGRAPH_URLS: Record<ChainId, string> = {
  [mainnet.id]: 'https://subgraph.staging.oasisapp.dev/summer-protocol-gov',
  [arbitrum.id]: 'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-arbitrum',
  [base.id]: 'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-base',
  [sonic.id]: 'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-sonic',
  [hyperliquid.id]: 'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-hyperliquid',
}

export const VIEM_CHAIN_ENTITIES: Record<ChainId, Chain> = {
  [mainnet.id]: mainnet,
  [arbitrum.id]: arbitrum,
  [base.id]: base,
  [sonic.id]: sonic,
  [hyperliquid.id]: hyperliquid,
}

/**
 * Creates a fallback transport from an array of RPC URLs.
 * Automatically retries with the next RPC if one fails.
 * Uses viem's built-in fallback transport for automatic retry logic.
 *
 * @param rpcUrls - Array of RPC URL strings
 * @returns A Transport instance with fallback/retry support
 */
export function createRpcTransport(rpcUrls: string[]): Transport {
  if (rpcUrls.length === 0) {
    throw new Error('At least one RPC URL is required')
  }

  // If only one URL, use simple http transport (no fallback needed)
  if (rpcUrls.length === 1) {
    return http(rpcUrls[0])
  }

  // Multiple URLs: use fallback transport for automatic retry
  return fallback(rpcUrls.map((url) => http(url)))
}
