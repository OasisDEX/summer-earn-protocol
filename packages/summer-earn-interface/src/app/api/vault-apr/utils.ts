import { CHAIN_PROTOCOL_SUBGRAPH_URLS } from '@/config/chains'
import { ChainId } from '@/types'

export interface InterestRate {
  id: string
  date: string
  averageRate: string
  sumRates: string
  updateCount: string
}

export interface VaultRates {
  id: string
  name: string | null
  symbol: string | null
  inputToken: {
    id: string
    symbol: string | null
    decimals: number
  }
  weeklyInterestRates: InterestRate[]
  dailyInterestRates: InterestRate[]
  hourlyInterestRates: InterestRate[]
}

export interface VaultAprData {
  chainId: ChainId
  vaults: VaultRates[]
  latestDates: {
    weekly: string | null
    daily: string | null
    hourly: string | null
  }
}

export interface CacheEntry {
  data: VaultAprData[]
  expiry: number
  lastUpdated: number
}

// Cache with 1 hour TTL
export const CACHE_TTL_MS = 60 * 60 * 1000
export const cache = new Map<string, CacheEntry>()

const VAULTS_QUERY = `
  query {
    vaults(first: 1000, orderBy: createdTimestamp, orderDirection: desc) {
      id
      name
      symbol
      inputToken {
        id
        symbol
        decimals
      }
      weeklyInterestRates(orderBy: date, orderDirection: desc, first: 1000) {
        id
        date
        averageRate
        sumRates
        updateCount
      }
      dailyInterestRates(orderBy: date, orderDirection: desc, first: 1000) {
        id
        date
        averageRate
        sumRates
        updateCount
      }
      hourlyInterestRates(orderBy: date, orderDirection: desc, first: 1000) {
        id
        date
        averageRate
        sumRates
        updateCount
      }
    }
  }
`

async function fetchVaultsFromChain(chainId: ChainId): Promise<VaultAprData | null> {
  const endpoint = CHAIN_PROTOCOL_SUBGRAPH_URLS[chainId]
  if (!endpoint) {
    return null
  }

  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: VAULTS_QUERY }),
      cache: 'no-store',
    })

    const json = await response.json()

    if (json.errors) {
      console.error(`Error fetching vaults for chain ${chainId}:`, json.errors)
      return null
    }

    const vaults: VaultRates[] = json.data?.vaults ?? []

    // Find latest dates across all vaults
    let latestWeekly: string | null = null
    let latestDaily: string | null = null
    let latestHourly: string | null = null

    for (const vault of vaults) {
      if (vault.weeklyInterestRates.length > 0) {
        const latest = vault.weeklyInterestRates[0].date
        if (!latestWeekly || BigInt(latest) > BigInt(latestWeekly)) {
          latestWeekly = latest
        }
      }
      if (vault.dailyInterestRates.length > 0) {
        const latest = vault.dailyInterestRates[0].date
        if (!latestDaily || BigInt(latest) > BigInt(latestDaily)) {
          latestDaily = latest
        }
      }
      if (vault.hourlyInterestRates.length > 0) {
        const latest = vault.hourlyInterestRates[0].date
        if (!latestHourly || BigInt(latest) > BigInt(latestHourly)) {
          latestHourly = latest
        }
      }
    }

    return {
      chainId,
      vaults,
      latestDates: {
        weekly: latestWeekly,
        daily: latestDaily,
        hourly: latestHourly,
      },
    }
  } catch (error) {
    console.error(`Failed to fetch vaults for chain ${chainId}:`, error)
    return null
  }
}

export async function fetchAllVaults(forceRefresh = false): Promise<VaultAprData[]> {
  const cacheKey = 'all-vaults-apr'
  const now = Date.now()
  const cached = cache.get(cacheKey)

  // Return cached data if valid and not forcing refresh
  if (!forceRefresh && cached && cached.expiry > now) {
    return cached.data
  }

  // Fetch from all chains in parallel
  const chainIds: ChainId[] = ['1', '42161', '8453', '146']
  const results = await Promise.all(chainIds.map((chainId) => fetchVaultsFromChain(chainId)))

  // Filter out null results
  const data = results.filter((result): result is VaultAprData => result !== null)

  // Update cache
  cache.set(cacheKey, {
    data,
    expiry: now + CACHE_TTL_MS,
    lastUpdated: now,
  })

  return data
}
