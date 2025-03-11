import { ChainConfig } from './types';
import {base, arbitrum, mainnet} from 'viem/chains';
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
]; 