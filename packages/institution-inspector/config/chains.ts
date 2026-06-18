import { mainnet, arbitrum, base, sonic, hyperliquid } from 'viem/chains'

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
}

export type NetworkType = 'base' | 'arbitrum' | 'mainnet' | 'sonic' | 'hyperliquid'

export const NETWORK_TO_CHAIN_ID: Record<NetworkType, number> = {
  base: base.id,
  arbitrum: arbitrum.id,
  mainnet: mainnet.id,
  sonic: sonic.id,
  hyperliquid: hyperliquid.id,
}

export const CHAIN_ID_TO_EXPLORER: Record<number, string> = {
  [mainnet.id]: 'https://etherscan.io',
  [arbitrum.id]: 'https://arbiscan.io',
  [base.id]: 'https://basescan.org',
  [sonic.id]: 'https://sonicscan.org',
  [hyperliquid.id]: 'https://hyperevmscan.io',
}
