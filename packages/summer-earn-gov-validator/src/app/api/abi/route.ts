import { NextRequest, NextResponse } from 'next/server'

// Exclusive Blockscout/Explorer mapping for Summer Earn Protocol
const BLOCKSCOUT_APIS: Record<string, string> = {
  '8453': 'https://base.blockscout.com/api',
  '42161': 'https://arbitrum.blockscout.com/api',
  '1': 'https://eth.blockscout.com/api',
  '10': 'https://optimism.blockscout.com/api',
  '34443': 'https://explorer.mode.network/api',
  '146': 'https://sonicscan.org/api',
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const address = searchParams.get('address')
  const chainId = searchParams.get('chainId')

  if (!address || !chainId) {
    return NextResponse.json({ error: 'Address and chainId are required' }, { status: 400 })
  }

  const apiUrl = BLOCKSCOUT_APIS[chainId]
  if (!apiUrl) {
    return NextResponse.json(
      { error: `Chain ID ${chainId} is not supported by the exclusive Blockscout provider` },
      { status: 400 },
    )
  }

  const fetchAbi = async (url: string, key?: string) => {
    const fullUrl = `${url}?module=contract&action=getabi&address=${address}${key ? `&apikey=${key}` : ''}`
    const response = await fetch(fullUrl)
    const data = await response.json()
    if (data.status === '1') return JSON.parse(data.result)
    throw new Error(data.result || 'Failed to fetch ABI')
  }

  try {
    // Exclusively use Blockscout for all supported chains
    const abi = await fetchAbi(apiUrl, process.env.BLOCKSCOUT_API_KEY)
    return NextResponse.json({ abi, source: 'blockscout' })
  } catch (error) {
    console.error('ABI Fetch Error:', error)
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'An error occurred' },
      { status: 500 },
    )
  }
}
