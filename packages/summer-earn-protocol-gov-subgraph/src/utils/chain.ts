// Create a map of dstEid to chainId
export const dstEidToChainIdMap = new Map<string, string>()
dstEidToChainIdMap.set('30101', '1') // Ethereum Mainnet
dstEidToChainIdMap.set('30110', '42161') // Arbitrum
dstEidToChainIdMap.set('30184', '8453') // Base
dstEidToChainIdMap.set('30332', '146') // Sonic

export const subgraphNetworkToChainIdMap = new Map<string, string>()
subgraphNetworkToChainIdMap.set('mainnet', '1')
subgraphNetworkToChainIdMap.set('arbitrum-one', '42161')
subgraphNetworkToChainIdMap.set('base', '8453')
subgraphNetworkToChainIdMap.set('sonic-mainnet', '146')

export function isHub(network: string): boolean {
  return network == 'base'
}
