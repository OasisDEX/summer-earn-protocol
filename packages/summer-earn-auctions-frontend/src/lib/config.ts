import { arbitrum, base, mainnet, sonic } from 'viem/chains'
import { ChainConfig } from './types'
export const CHAIN_CONFIGS: ChainConfig[] = [
  {
    name: 'Ethereum',
    id: 1,
    chain: mainnet,
    subgraphEndpoint: 'https://subgraph.staging.oasisapp.dev/summer-auctions',
    raftAddress: '0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E',
    rpcUrl: process.env.MAINNET_RPC_URL || '',
  },
  {
    name: 'Base',
    id: 8453,
    chain: base,
    subgraphEndpoint: 'https://subgraph.staging.oasisapp.dev/summer-auctions-base',
    raftAddress: '0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E',
    rpcUrl: process.env.BASE_RPC_URL || '',
  },
  {
    name: 'Arbitrum',
    id: 42161,
    chain: arbitrum,
    subgraphEndpoint: 'https://subgraph.staging.oasisapp.dev/summer-auctions-arbitrum',
    raftAddress: '0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E',
    rpcUrl: process.env.ARBITRUM_RPC_URL || '',
  },
  {
    name: 'Sonic',
    id: 146,
    chain: sonic,
    subgraphEndpoint: 'https://subgraph.staging.oasisapp.dev/summer-auctions-sonic',
    raftAddress: '0x6E6b9CB3BA753337ab91BC5A1dbAD83b8F05e204',
    rpcUrl: process.env.SONIC_RPC_URL || '',
  },
]
