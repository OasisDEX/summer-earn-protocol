import { type PriceFeedSource, type PricePoint, type PriceSeries,RANGE_TO_SECONDS } from './types'

interface DefiLlamaChartResponse {
  coins: Record<
    string,
    {
      decimals?: number
      symbol?: string
      prices: Array<{ timestamp: number; price: number; confidence?: number }>
    }
  >
}

// DeFiLlama coins/chart endpoint. Address-keyed (`base:0x...`), free, no key.
// We sample 1 point per day (`period=86400`) for the requested span; for the
// '7d' range we drop to hourly for nicer resolution.
export function createDefiLlamaSource(): PriceFeedSource {
  return {
    name: 'defillama',
    async fetchSeries({ chainId, token, range }) {
      // DeFiLlama is keyed by chain *slug*, not chainId. Single-chain app
      // (Base) — hardcode the slug.
      if (chainId !== '8453') return null

      const nowSec = Math.floor(Date.now() / 1000)
      const period = range === '7d' ? 3600 : 86_400
      const spanSeconds = range === 'all' ? 365 * 24 * 60 * 60 : RANGE_TO_SECONDS[range]
      const startSec = nowSec - spanSeconds
      const span = Math.ceil(spanSeconds / period)

      const url = new URL(
        `https://coins.llama.fi/chart/base:${token.toLowerCase()}`,
      )
      url.searchParams.set('start', String(startSec))
      url.searchParams.set('period', String(period))
      url.searchParams.set('span', String(span))
      url.searchParams.set('searchWidth', '600')

      const res = await fetch(url, {
        headers: { accept: 'application/json' },
        // The caller (route handler) wraps this in 'use cache'; we don't add
        // another layer here.
        cache: 'no-store',
      })
      if (!res.ok) return null

      const body = (await res.json()) as DefiLlamaChartResponse
      const key = `base:${token.toLowerCase()}`
      const entry = body.coins?.[key]
      if (!entry || !entry.prices || entry.prices.length === 0) return null

      const points: PricePoint[] = entry.prices.map((p) => ({
        t: p.timestamp * 1000,
        p: p.price,
      }))

      return {
        chainId,
        token: token.toLowerCase() as PriceSeries['token'],
        range,
        points,
        gaps: [],
        source: 'defillama',
        basis: 'off-chain-aggregate',
      }
    },
  }
}
