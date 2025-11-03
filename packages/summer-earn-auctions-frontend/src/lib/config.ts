import { arbitrum, base, mainnet, sonic } from 'viem/chains'

import { ChainConfig } from './types'

// Validate RPC URLs
const validateRpcUrl = (url: string | undefined, chainName: string) => {
  if (!url) {
    console.warn(
      `Missing RPC URL for ${chainName}. Please set the ${chainName.toUpperCase()}_RPC_URL environment variable.`,
    )
    return `https://${chainName.toLowerCase()}.infura.io/v3/your-infura-key` // Fallback for development
  }
  return url
}

// Get environment variables in a way that works on both client and server
const getEnvVar = (name: string): string | undefined => {
  if (typeof window === 'undefined') {
    // Server-side
    return process.env[name]
  } else {
    // Client-side (only NEXT_PUBLIC_ prefixed env vars are accessible)
    return (process.env as Record<string, string | undefined>)[`NEXT_PUBLIC_${name}`]
  }
}

export const CHAIN_CONFIGS: Record<number, ChainConfig> = {
  [mainnet.id]: {
    name: 'Ethereum',
    id: mainnet.id,
    chain: mainnet,
    subgraphEndpoint: 'https://subgraph.staging.oasisapp.dev/summer-auctions',
    raftAddress: '0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E',
    rpcUrl: validateRpcUrl(getEnvVar('MAINNET_RPC_URL'), 'Ethereum'),
  },
  [base.id]: {
    name: 'Base',
    id: base.id,
    chain: base,
    subgraphEndpoint: 'https://subgraph.staging.oasisapp.dev/summer-auctions-base',
    raftAddress: '0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E',
    rpcUrl: validateRpcUrl(getEnvVar('BASE_RPC_URL'), 'Base'),
  },
  [arbitrum.id]: {
    name: 'Arbitrum',
    id: arbitrum.id,
    chain: arbitrum,
    subgraphEndpoint: 'https://subgraph.staging.oasisapp.dev/summer-auctions-arbitrum',
    raftAddress: '0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E',
    rpcUrl: validateRpcUrl(getEnvVar('ARBITRUM_RPC_URL'), 'Arbitrum'),
  },
  [sonic.id]: {
    name: 'Sonic',
    id: sonic.id,
    chain: sonic,
    subgraphEndpoint: 'https://subgraph.staging.oasisapp.dev/summer-auctions-sonic',
    raftAddress: '0x6E6b9CB3BA753337ab91BC5A1dbAD83b8F05e204',
    rpcUrl: validateRpcUrl(getEnvVar('SONIC_RPC_URL'), 'Optimism'),
  },
}
