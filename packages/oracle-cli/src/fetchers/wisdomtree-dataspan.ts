import fs from 'fs/promises'
import path from 'path'
import { fetchWithPlaywright } from './wisdomtree-api-base'

export interface NAVData {
  ticker: string
  relatedTicker: string | null
  name: string
  dt: string
  nav: number
  sharesOutstanding: number
  aum: number
  navPrevious: number
  navDelta: number
  navDeltaPCT: number
}

const CACHE_DIR = path.resolve(process.cwd(), '.wt-nav-cache')

export interface BlockchainAddress {
  wtID: number
  blockchainName: string
  tokenSymbol: string
  contractAddress: string
}

export async function fetchNAV(ticker: string, date?: string): Promise<NAVData> {
  const tickerLower = ticker.toLowerCase()
  const cachePath = date ? path.join(CACHE_DIR, tickerLower, `${date}.json`) : null

  // Check cache for historical data
  if (cachePath) {
    try {
      const cached = await fs.readFile(cachePath, 'utf-8')
      return JSON.parse(cached)
    } catch {
      // Not in cache, proceed to fetch
    }
  }

  const url = `https://dataspanapi.wisdomtree.com/funddetails/nav/?ticker=${ticker}${date ? `&date=${date}` : ''}`

  const data = await fetchWithPlaywright<NAVData>(url)

  // Cache historical data
  if (cachePath && data.dt === date) {
    await fs.mkdir(path.dirname(cachePath), { recursive: true })
    await fs.writeFile(cachePath, JSON.stringify(data, null, 2))
  }

  return data
}

export async function fetchBlockchainAddresses(ticker: string): Promise<BlockchainAddress[]> {
  const url = `https://dataspanapi.wisdomtree.com/funddetails/blockchain_addresses/?ticker=${ticker}`
  return await fetchWithPlaywright<BlockchainAddress[]>(url)
}
