import { Abi } from 'viem'

// Exclusive Blockscout/Explorer mapping for Summer Earn Protocol
export const BLOCKSCOUT_APIS: Record<string, string> = {
  '8453': 'https://base.blockscout.com/api',
  '42161': 'https://arbitrum.blockscout.com/api',
  '1': 'https://eth.blockscout.com/api',
  '10': 'https://optimism.blockscout.com/api',
  '34443': 'https://explorer.mode.network/api',
  '146': 'https://api.sonicscan.org/api',
}

export const fetchAbi = async (url: string, targetAddress: string, key?: string): Promise<Abi> => {
  const fullUrl = `${url}?module=contract&action=getabi&address=${targetAddress}${key ? `&apikey=${key}` : ''}`
  const response = await fetch(fullUrl)
  const data = await response.json()
  if (data.status === '1') {
    const parsedData = JSON.parse(data.result) as Abi
    return parsedData
  }

  throw new Error(data.result || 'Failed to fetch ABI')
}

export const getImplementationAddress = async (
  url: string,
  targetAddress: string,
  key?: string,
) => {
  try {
    const fullUrl = `${url}?module=contract&action=getsourcecode&address=${targetAddress}${key ? `&apikey=${key}` : ''}`
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
