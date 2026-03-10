import { fetchWithPlaywright } from './wisdomtree-api-base'

/**
 * WisdomTree Variable NAV fetcher.
 * Fetches NAV data from the WisdomTree DataSpan API using shared Playwright utility.
 */

export interface OracleData {
  ticker: string
  nav: number
  dt: string // YYYY-MM-DD
  timestamp: number // Unix timestamp of the data
}

export async function fetchOracleData(ticker: string): Promise<OracleData> {
  const url = `https://dataspanapi.wisdomtree.com/funddetails/nav/?ticker=${ticker}`

  const data = await fetchWithPlaywright<{ ticker?: string; nav?: number; dt?: string }>(url)

  if (!data || !data.nav || !data.dt) {
    throw new Error('Malformed API response: Missing NAV or Date')
  }

  // The data.dt is in 'YYYY-MM-DD' format.
  // WisdomTree NAV strikes at 4:00 PM Eastern Time.
  // We need to parse this string into a proper timestamp representing 16:00 ET.
  const [year, month, day] = data.dt.split('-').map(Number)

  const utcMidnight = new Date(Date.UTC(year, month - 1, day))

  const nyDateString = new Date(
    utcMidnight.toLocaleString('en-US', { timeZone: 'America/New_York' }),
  )
  const offsetDiff = utcMidnight.getTime() - nyDateString.getTime()

  // Calculate 16:00 (4 PM) UTC
  const utc1600 = new Date(Date.UTC(year, month - 1, day, 16, 0, 0))
  // Apply offset to shift 16:00 UTC to 16:00 ET
  const targetTimeMs = utc1600.getTime() + offsetDiff

  const timestamp = Math.floor(targetTimeMs / 1000)

  return {
    ticker: data.ticker ?? ticker,
    nav: data.nav,
    dt: data.dt,
    timestamp,
  }
}
