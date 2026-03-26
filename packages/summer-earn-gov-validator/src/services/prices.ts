const COINGECKO_API_KEY = process.env.COINGECKO_API_KEY

const COINGECKO_IDS: Record<string, string> = {
  SUMMER: 'summer-2',
  ETH: 'ethereum',
  WETH: 'ethereum',
  USDC: 'usd-coin',
  'USDC.e': 'usd-coin',
  USDT: 'tether',
  DAI: 'dai',
  WBTC: 'wrapped-bitcoin',
  wSonic: 'sonic-3',
  wHYPE: 'hyperliquid',
}

export interface PriceResponse {
  prices: Record<string, number>
  error?: string
}

export async function fetchPrices(symbols: string[]): Promise<PriceResponse> {
  const uniqueSymbols = [...new Set(symbols)]
  const ids = [...new Set(uniqueSymbols.map((s) => COINGECKO_IDS[s]).filter(Boolean))].join(',')

  if (!ids) return { prices: {} }

  try {
    const url = `https://api.coingecko.com/api/v3/simple/price?ids=${ids}&vs_currencies=usd&x_cg_demo_api_key=${COINGECKO_API_KEY}`

    const response = await fetch(url, {
      next: {
        revalidate: 3600, // 1 hour cache
      },
    })

    if (!response.ok) {
      if (response.status === 429) {
        return {
          prices: {},
          error: 'CoinGecko rate limit reached. Treasury values may be inaccurate.',
        }
      }
      throw new Error(`CoinGecko API error: ${response.statusText}`)
    }

    const data = await response.json()

    const prices: Record<string, number> = {}
    uniqueSymbols.forEach((symbol) => {
      const id = COINGECKO_IDS[symbol]
      if (id && data[id]) {
        prices[symbol] = data[id].usd
      }
    })

    return { prices }
  } catch (error) {
    console.error('Error fetching prices from CoinGecko:', error)
    return {
      prices: {},
      error: 'Failed to fetch real-time prices. Using stale data.',
    }
  }
}
