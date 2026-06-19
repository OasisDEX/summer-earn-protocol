import { mainnet, arbitrum, base, sonic, hyperliquid, sepolia, type Chain } from 'viem/chains'

// Public RPC endpoints per chain (fallback transport tries them in order).
// Copied from oracle-dashboard; trimmed to the primary handful per chain.
export const CHAIN_RPC_URLS: Record<number, string[]> = {
  [mainnet.id]: [
    'https://eth.llamarpc.com',
    'https://ethereum-rpc.publicnode.com',
    'https://eth.drpc.org',
    'https://1rpc.io/eth',
  ],
  [arbitrum.id]: [
    'https://arb1.arbitrum.io/rpc',
    'https://arbitrum-one-rpc.publicnode.com',
    'https://arbitrum.drpc.org',
    'https://1rpc.io/arb',
  ],
  [base.id]: [
    'https://mainnet.base.org',
    'https://base-rpc.publicnode.com',
    'https://base.llamarpc.com',
    'https://base.drpc.org',
    'https://1rpc.io/base',
  ],
  [sonic.id]: ['https://sonic.api.onfinality.io/public'],
  [hyperliquid.id]: [hyperliquid.rpcUrls.default.http[0] as string],
  [sepolia.id]: [
    'https://ethereum-sepolia-rpc.publicnode.com',
    'https://sepolia.drpc.org',
    'https://1rpc.io/sepolia',
  ],
}

// `sepolia_mainnet` matches the deployment config/network key (Ethereum Sepolia testnet).
export type NetworkType =
  | 'base'
  | 'arbitrum'
  | 'mainnet'
  | 'sonic'
  | 'hyperliquid'
  | 'sepolia_mainnet'

export const NETWORK_TO_CHAIN_ID: Record<NetworkType, number> = {
  base: base.id,
  arbitrum: arbitrum.id,
  mainnet: mainnet.id,
  sonic: sonic.id,
  hyperliquid: hyperliquid.id,
  sepolia_mainnet: sepolia.id,
}

const VIEM_CHAINS: Record<NetworkType, Chain> = {
  base,
  arbitrum,
  mainnet,
  sonic,
  hyperliquid,
  sepolia_mainnet: sepolia,
}
export const viemChainFor = (network: string): Chain | undefined =>
  VIEM_CHAINS[network as NetworkType]

export const CHAIN_ID_TO_EXPLORER: Record<number, string> = {
  [mainnet.id]: 'https://etherscan.io',
  [arbitrum.id]: 'https://arbiscan.io',
  [base.id]: 'https://basescan.org',
  [sonic.id]: 'https://sonicscan.org',
  [hyperliquid.id]: 'https://hyperevmscan.io',
  [sepolia.id]: 'https://sepolia.etherscan.io',
}
