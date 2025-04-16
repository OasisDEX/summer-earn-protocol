export function getChainIdByNetworkName(network: string): number {
  if (network == 'mainnet') {
    return 1
  } else if (network == 'arbitrum-one') {
    return 42161
  } else if (network == 'optimism') {
    return 10
  } else if (network == 'polygon') {
    return 137
  } else if (network == 'base') {
    return 8453
  } else if (network == 'sonic-mainnet') {
    return 146
  } else {
    throw new Error(`Unsupported network: ${network}`)
  }
}

export function getNetworkNameByChainId(chainId: number): string {
  switch (chainId) {
    case 1:
      return 'mainnet'
    case 8453:
      return 'base'
    case 42161:
      return 'arbitrum-one'
    case 10:
      return 'optimism'
    case 137:
      return 'polygon'
    case 146:
      return 'sonic-mainnet'
    default:
      throw new Error(`Unsupported chain ID: ${chainId}`)
  }
}
