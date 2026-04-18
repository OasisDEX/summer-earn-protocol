import { getSecret } from '@/lib/secrets'

export async function getPrices(ids: string) {
  let coingeckoApiKey: string
  try {
    coingeckoApiKey = await getSecret('COINGECKO_API_KEY')
  } catch (error: any) {
    console.error('Failed to fetch COINGECKO_API_KEY from SSM:', error)
    throw new Error(`Price service initialization failed: ${error.message}`)
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
      throw new Error(`CoinGecko API failed with status ${response.status}: ${JSON.stringify(errorData)}`)
    }

    const data = await response.json()
    return data
  } catch (error: any) {
    console.error(`Error fetching prices for IDs ${ids}:`, error)
    throw error // Propagate for diagnostic visibility in the API response
  }
}
