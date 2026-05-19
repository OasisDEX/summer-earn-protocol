import { Abi } from 'viem'

import { getSecret } from './secrets'

export enum AbiFetcherType {
  Etherscan = 'etherscan',
  Blockscout = 'blockscout',
  Sourcify = 'sourcify',
}

export const ABI_FETCHER_CONFIG: Record<
  string,
  { type: AbiFetcherType; apiUrl?: string; apiKeyEnv?: string }
> = {
  '8453': {
    type: AbiFetcherType.Blockscout,
    apiUrl: 'https://api.blockscout.com/v2/api?chainId=8453&',
    apiKeyEnv: 'BLOCKSCOUT_API_KEY',
  },
  '42161': {
    type: AbiFetcherType.Blockscout,
    apiUrl: 'https://api.blockscout.com/v2/api?chainId=42161&',
    apiKeyEnv: 'BLOCKSCOUT_API_KEY',
  },
  '1': {
    type: AbiFetcherType.Blockscout,
    apiUrl: 'https://api.blockscout.com/v2/api?chainId=1&',
    apiKeyEnv: 'BLOCKSCOUT_API_KEY',
  },
  '146': {
    type: AbiFetcherType.Etherscan,
    apiUrl: 'https://api.etherscan.io/v2/api?chainid=146&',
    apiKeyEnv: 'ETHERSCAN_API_KEY',
  },
}

export const getAbiFetcher = async (chainId: string): Promise<AbiFetcher> => {
  const config = ABI_FETCHER_CONFIG[chainId]
  if (!config) {
    throw new Error(`Chain ID ${chainId} is not supported for ABI fetching`)
  }

  const resolvedApiKey = config.apiKeyEnv ? await getSecret(config.apiKeyEnv) : undefined
  return new AbiFetcher(config.type, { apiUrl: config.apiUrl, apiKey: resolvedApiKey })
}

export interface IAbiFetcher {
  fetchAbi(address: string, chainId: number): Promise<Abi>
  getImplementationAddress(address: string, chainId: number): Promise<string | null>
}

export class ExplorerAbiFetcher implements IAbiFetcher {
  constructor(
    private apiUrl: string,
    private apiKey?: string,
  ) {}

  async fetchAbi(address: string): Promise<Abi> {
    const fullUrl = `${this.apiUrl}module=contract&action=getabi&address=${address}${
      this.apiKey ? `&apikey=${this.apiKey}` : ''
    }`
    const response = await fetch(fullUrl)
    const data = await response.json()
    if (data.status === '1') {
      return JSON.parse(data.result) as Abi
    }

    throw new Error(data.result || 'Failed to fetch ABI')
  }

  async getImplementationAddress(address: string): Promise<string | null> {
    try {
      const fullUrl = `${this.apiUrl}module=contract&action=getsourcecode&address=${address}${
        this.apiKey ? `&apikey=${this.apiKey}` : ''
      }`
      const response = await fetch(fullUrl)
      const data = await response.json()
      if (data.status === '1' && data.result && data.result[0]) {
        const result = data.result[0]
        const isProxy = result.IsProxy === 'true' || result.Proxy === '1'
        const implementation = result.ImplementationAddress || result.Implementation
        if (
          isProxy &&
          implementation &&
          implementation !== '0x0000000000000000000000000000000000000000'
        ) {
          return implementation as string
        }
      }
    } catch (e) {
      console.error('Error checking proxy status:', e)
    }
    return null
  }
}

export interface SourcifyProxyResolution {
  isProxy: boolean
  proxyType: string | null
  implementations: { address: string; name: string }[]
  proxyResolutionError?: {
    customCode: string
    message: string
    errorId: string
  }
}

export interface SourcifyContractResponse {
  match: string | null
  creationMatch: string | null
  runtimeMatch: string | null
  chainId: string
  address: string
  verifiedAt?: string
  abi?: Abi
  proxyResolution?: SourcifyProxyResolution
}

export class SourcifyAbiFetcher implements IAbiFetcher {
  constructor(private baseUrl: string = 'https://sourcify.dev/server') {}

  async fetchAbi(address: string, chainId: number): Promise<Abi> {
    const fullUrl = `${this.baseUrl}/v2/contract/${chainId}/${address}?fields=abi`
    const response = await fetch(fullUrl)
    const data = (await response.json()) as SourcifyContractResponse
    console.log({ data })
    if (data.abi) {
      return data.abi
    }

    if (!data.match) {
      throw new Error('Contract not verified on Sourcify')
    }

    throw new Error('Failed to fetch ABI from Sourcify')
  }

  async getImplementationAddress(address: string, chainId: number): Promise<string | null> {
    try {
      const fullUrl = `${this.baseUrl}/v2/contract/${chainId}/${address}?fields=proxyResolution`
      const response = await fetch(fullUrl)
      const data = (await response.json()) as SourcifyContractResponse

      if (data.proxyResolution?.isProxy) {
        const implementations = data.proxyResolution.implementations
        if (implementations && implementations.length > 0) {
          return implementations[0].address
        }
      }
    } catch (e) {
      console.error('Error checking proxy status on Sourcify:', e)
    }
    return null
  }
}

export class EtherscanAbiFetcher extends ExplorerAbiFetcher {}
export class BlockscoutAbiFetcher extends ExplorerAbiFetcher {}

export class AbiFetcher implements IAbiFetcher {
  private fetcher: IAbiFetcher

  constructor(type: AbiFetcherType, options: { apiUrl?: string; apiKey?: string } = {}) {
    switch (type) {
      case AbiFetcherType.Etherscan:
        if (!options.apiUrl) throw new Error('apiUrl is required for Etherscan')
        this.fetcher = new EtherscanAbiFetcher(options.apiUrl, options.apiKey)
        break
      case AbiFetcherType.Blockscout:
        if (!options.apiUrl) throw new Error('apiUrl is required for Blockscout')
        this.fetcher = new BlockscoutAbiFetcher(options.apiUrl, options.apiKey)
        break
      case AbiFetcherType.Sourcify:
        this.fetcher = new SourcifyAbiFetcher(options.apiUrl)
        break
      default:
        throw new Error(`Unknown fetcher type: ${type}`)
    }
  }

  async fetchAbi(address: string, chainId: number): Promise<Abi> {
    return this.fetcher.fetchAbi(address, chainId)
  }

  async getImplementationAddress(address: string, chainId: number): Promise<string | null> {
    return this.fetcher.getImplementationAddress(address, chainId)
  }
}

// Keep legacy exports for compatibility
export const fetchAbi = async (url: string, targetAddress: string, key?: string): Promise<Abi> => {
  const fetcher = new ExplorerAbiFetcher(url, key)
  return fetcher.fetchAbi(targetAddress)
}

export const getImplementationAddress = async (
  url: string,
  targetAddress: string,
  key?: string,
) => {
  const fetcher = new ExplorerAbiFetcher(url, key)
  return fetcher.getImplementationAddress(targetAddress)
}
