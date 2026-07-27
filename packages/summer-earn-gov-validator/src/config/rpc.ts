import { createPublicClient, fallback, http, type PublicClient, type Transport } from 'viem'
import { arbitrum, base, Chain, hyperliquid, mainnet, sonic } from 'viem/chains'

const MULTICALL_ADDRESS = '0xcA11bde05977b3631167028862bE2a173976CA11' as const

const createChainWithMulticall = (chain: Chain): Chain => ({
  ...chain,
  contracts: {
    ...chain.contracts,
    multicall3: {
      address: MULTICALL_ADDRESS,
    },
  },
})

export const VIEM_CHAIN_ENTITIES: Record<number, Chain> = {
  [mainnet.id]: createChainWithMulticall(mainnet),
  [arbitrum.id]: createChainWithMulticall(arbitrum),
  [base.id]: createChainWithMulticall(base),
  [sonic.id]: createChainWithMulticall(sonic),
  [hyperliquid.id]: createChainWithMulticall(hyperliquid),
}

export const CHAIN_RPC_URLS: Record<number, string[]> = {
  [mainnet.id]: [
    'https://rpc.mevblocker.io/noreverts',
    'https://eth.llamarpc.com',
    'https://ethereum-rpc.publicnode.com',
    'https://eth.rpc.blxrbdn.com',
    'https://eth-mainnet.public.blastapi.io',
    'https://ethereum.public.blockpi.network/v1/rpc/public',
    'https://ethereum-mainnet.gateway.tatum.io',
    'https://0xrpc.io/eth',
    'https://eth1.lava.build',
    'https://eth.api.pocket.network',
    'https://rpc.eth.gateway.fm',
    'https://eth.meowrpc.com',
    'https://ethereum-public.nodies.app',
    'https://eth.api.onfinality.io/public',
    'https://ethereum.rpc.subquery.network/public',
    'https://eth.drpc.org',
    'https://rpc.fullsend.to',
    'https://rpc.mevblocker.io',
    'https://rpc.mevblocker.io/fast',
    'https://eth.merkle.io',
    'https://1rpc.io/eth',
    'https://ethereum-json-rpc.stakely.io',
    'https://cloudflare-eth.com',
    'https://eth-mainnet-public.unifra.io',
  ],
  [arbitrum.id]: [
    'https://arb1.arbitrum.io/rpc',
    'https://arbitrum-one-public.nodies.app',
    'https://arbitrum-one-rpc.publicnode.com',
    'https://arb1.lava.build',
    'https://public-arb-mainnet.fastnode.io',
    'https://arbitrum-one.public.blastapi.io',
    'https://arb-one-mainnet.gateway.tatum.io',
    'https://arbitrum.gateway.tenderly.co',
    'https://arbitrum.rpc.subquery.network/public',
    'https://arbitrum.meowrpc.com',
    'https://arb-one.api.pocket.network',
    'https://api.zan.top/arb-one',
    'https://rpc.sentio.xyz/arbitrum-one',
    'https://rpc.owlracle.info/arb/70d38ce1826c4a60bb2a8e05a6c8b20f',
    'https://1rpc.io/arb',
    'https://arbitrum.drpc.org',
    'https://arbitrum.public.blockpi.network/v1/rpc/public',
    'https://rpc.arb1.arbitrum.gateway.fm',
    'https://arb-mainnet-public.unifra.io',
    'https://public.stackup.sh/api/v1/node/arbitrum-one',
    'https://endpoints.omniatech.io/v1/arbitrum/one/public',
    'https://arbitrum.api.onfinality.io/public',
    'https://arbitrum.therpc.io',
    'https://rpc.poolz.finance/arbitrum',
  ],
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
    'https://base.api.pocket.network',
    'https://api-base-mainnet-archive.n.dwellir.com/2ccf18bf-2916-4198-8856-42172854353c',
    'https://mainnet.base.org',
    'https://base.rpc.blxrbdn.com',
    'https://rpc.sentio.xyz/base',
    'https://developer-access-mainnet.base.org',
    'https://base.rpc.subquery.network/public',
    'https://api.zan.top/base-mainnet',
    'https://endpoints.omniatech.io/v1/base/mainnet/public',
    'https://public.stackup.sh/api/v1/node/base-mainnet',
    'https://base-mainnet.gateway.tatum.io',
  ],
  [sonic.id]: [
    'https://rpc.soniclabs.com',
    'https://sonic.drpc.org',
    'https://sonic-json-rpc.stakely.io',
    'https://sonic-rpc.publicnode.com',
    'https://rpc.sentio.xyz/sonic-mainnet',
    'https://sonic.api.pocket.network',
    'https://api-sonic-mainnet-archive.n.dwellir.com/2ccf18bf-2916-4198-8856-42172854353c',
    'https://sonic.therpc.io',
    'https://sonic.api.onfinality.io/public',
    'https://rpc.ankr.com/sonic_mainnet',
  ],
  [hyperliquid.id]: ['https://rpc.hyperliquid.xyz/evm'],
}

/**
 * Creates a fallback transport from an array of RPC URLs.
 */
export function createRpcTransport(rpcUrls: string[]): Transport {
  if (!rpcUrls || rpcUrls.length === 0) {
    throw new Error('At least one RPC URL is required')
  }

  if (rpcUrls.length === 1) {
    return http(rpcUrls[0])
  }

  return fallback(rpcUrls.map((url) => http(url)))
}

// Reuse one public client per chain — creating a client (and its fallback transport)
// on every call is wasteful when many reads target the same chain in one render.
const publicClientCache: Record<number, PublicClient> = {}

/**
 * Gets a public client for a given chainId.
 * @param chainId
 * @returns A PublicClient instance with fallback/retry support
 */
export function getPublicClient(chainId: number): PublicClient {
  const cached = publicClientCache[chainId]
  if (cached) return cached

  const rpcUrls = CHAIN_RPC_URLS[chainId]
  const chain = VIEM_CHAIN_ENTITIES[chainId]

  if (!rpcUrls || !chain) {
    throw new Error(`Unsupported chainId: ${chainId}`)
  }

  const client = createPublicClient({
    transport: createRpcTransport(rpcUrls),
    chain,
    // Aggregate same-tick readContract calls into one Multicall3 request —
    // Promise.all bursts (slipstream ownerOf/positions, ENS reverse lookups)
    // become a single round-trip instead of one HTTP request per call.
    batch: { multicall: true },
  })
  publicClientCache[chainId] = client
  return client
}
