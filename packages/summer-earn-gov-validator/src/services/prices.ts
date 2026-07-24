import { getSecret } from '@/lib/secrets'

const SYMBOL_TO_ID: Record<string, string> = {
  SUM: 'summer-fi',
  ETH: 'ethereum',
  WETH: 'weth',
  USDC: 'usd-coin',
  USDT: 'tether',
  DAI: 'dai',
  RETH: 'rocket-pool-eth',
  WSTETH: 'wrapped-staked-ether',
  CBETH: 'coinbase-wrapped-staked-eth',
  CRV: 'curve-dao-token',
  LDO: 'lido-dao',
  LINK: 'chainlink',
  USDS: 'usds',
  AERO: 'aerodrome-finance',
  VEAERO: 'aerodrome-finance', // veAERO is locked AERO; valued at the AERO spot price
}

export interface PriceResponse {
  prices: Record<string, number>
  error: string | undefined
}

export async function getPrices(symbols: string | string[]): Promise<PriceResponse> {
  const symbolArray = Array.isArray(symbols) ? symbols : [symbols]
  const ids = symbolArray.map((s) => SYMBOL_TO_ID[s.toUpperCase()] || s.toLowerCase()).join(',')

  let coingeckoApiKey: string
  try {
    coingeckoApiKey = await getSecret('COINGECKO_API_KEY')
  } catch (error: any) {
    console.error('Failed to fetch COINGECKO_API_KEY from SSM:', error)
    return {
      prices: {} as Record<string, number>,
      error: `Price service initialization failed: ${error.message}`,
    }
  }

  try {
    const url = `https://api.coingecko.com/api/v3/simple/price?ids=${ids}&vs_currencies=usd&x_cg_demo_api_key=${coingeckoApiKey}`
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        accept: 'application/json',
      },
    })

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}))
      console.error('CoinGecko API error:', {
        status: response.status,
        statusText: response.statusText,
        errorData,
      })
      return {
        prices: {} as Record<string, number>,
        error: `CoinGecko API failed with status ${response.status}`,
      }
    }

    const data = await response.json()

    // Map IDs back to Symbols for the treasury service
    const prices: Record<string, number> = {}
    symbolArray.forEach((symbol) => {
      const id = SYMBOL_TO_ID[symbol.toUpperCase()] || symbol.toLowerCase()
      if (data[id]) {
        prices[symbol] = data[id].usd
      }
    })

    return { prices, error: undefined }
  } catch (error: any) {
    console.error(`Error fetching prices for symbols ${symbolArray.join(',')}:`, error)
    return { prices: {} as Record<string, number>, error: error.message }
  }
}
