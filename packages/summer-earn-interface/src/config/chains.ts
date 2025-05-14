import { Chain, arbitrum, base, mainnet, sonic } from 'viem/chains'
import { ChainId } from '../types'

export const CHAIN_NAMES: Record<ChainId, string> = {
  [mainnet.id]: 'Ethereum',
  [arbitrum.id]: 'Arbitrum',
  [base.id]: 'Base',
  [sonic.id]: 'Sonic',
}

export const CHAIN_RPC_URLS: Record<ChainId, string> = {
  [mainnet.id]: 'https://mainnet.gateway.tenderly.co',
  [arbitrum.id]: 'https://arb1.arbitrum.io/rpc',
  [base.id]: 'https://0xrpc.io/base',
  [sonic.id]: 'https://rpc.ankr.com/sonic_mainnet',
}

export const CHAIN_BLOCK_EXPLORERS: Record<ChainId, string> = {
  [mainnet.id]: 'https://etherscan.io',
  [arbitrum.id]: 'https://arbiscan.io',
  [base.id]: 'https://basescan.org',
  [sonic.id]: 'https://explorer.sonic.network',
}

export const VIEM_CHAIN_ENTITIES: Record<ChainId, Chain> = {
  [mainnet.id]: mainnet,
  [arbitrum.id]: arbitrum,
  [base.id]: base,
  [sonic.id]: sonic,
}
