import { arbitrum, base, mainnet, sonic } from 'viem/chains'
import { ChainConfig } from './types'

// Validate RPC URLs
const validateRpcUrl = (url: string, chainName: string) => {
  if (!url) {
    throw new Error(
      `Missing RPC URL for ${chainName}. Please set the ${chainName.toUpperCase()}_RPC_URL environment variable.`,
    )
  }
  return url
}

export const CHAIN_CONFIGS: ChainConfig[] = [
  {
    name: 'Ethereum',
    id: 1,
    chain: mainnet,
    subgraphEndpoint: 'https://subgraph.staging.oasisapp.dev/summer-auctions',
    raftAddress: '0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E',
    rpcUrl: validateRpcUrl(process.env.MAINNET_RPC_URL || '', 'Ethereum'),
  },
  {
    name: 'Base',
    id: 8453,
    chain: base,
    subgraphEndpoint: 'https://subgraph.staging.oasisapp.dev/summer-auctions-base',
    raftAddress: '0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E',
    rpcUrl: validateRpcUrl(process.env.BASE_RPC_URL || '', 'Base'),
  },
  {
    name: 'Arbitrum',
    id: 42161,
    chain: arbitrum,
    subgraphEndpoint: 'https://subgraph.staging.oasisapp.dev/summer-auctions-arbitrum',
    raftAddress: '0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E',
    rpcUrl: validateRpcUrl(process.env.ARBITRUM_RPC_URL || '', 'Arbitrum'),
  },
  {
    name: 'Sonic',
    id: 146,
    chain: sonic,
    subgraphEndpoint: 'https://subgraph.staging.oasisapp.dev/summer-auctions-sonic',
    raftAddress: '0x6E6b9CB3BA753337ab91BC5A1dbAD83b8F05e204',
    rpcUrl: validateRpcUrl(process.env.SONIC_RPC_URL || '', 'Sonic'),
  },
]
