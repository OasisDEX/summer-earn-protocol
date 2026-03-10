/**
 * WisdomTree Variable NAV fetcher.
 * Fetches NAV data from the WisdomTree DataSpan API.
 */

export interface OracleData {
  ticker: string
  nav: number
  dt: string // YYYY-MM-DD
  timestamp: number // Unix timestamp of the data
}

const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms))

/**
 * Fetches NAV data with a retry mechanism and realistic headers to bypass basic bot detection.
 */
export async function fetchOracleData(ticker: string, retries = 2): Promise<OracleData> {
  const url = `https://dataspanapi.wisdomtree.com/funddetails/nav/?ticker=${ticker}`

  for (let i = 0; i < retries; i++) {
    try {
      const response = await fetch(url, {
        method: 'GET',
        signal: AbortSignal.timeout(10000),
      })

      if (response.status === 403) {
        throw new Error('Cloudflare Block (403 Forbidden).')
      }

      if (!response.ok) {
        throw new Error(`HTTP Error ${response.status}: ${response.statusText}`)
      }

      const data = (await response.json()) as { ticker?: string; nav?: number; dt?: string }

      if (!data || !data.nav || !data.dt) {
        throw new Error('Malformed API response: Missing NAV or Date')
      }

      // The data.dt is in 'YYYY-MM-DD' format.
      // WisdomTree NAV strikes at 4:00 PM Eastern Time.
      // We need to parse this string into a proper timestamp representing 16:00 ET.
      const [year, month, day] = data.dt.split('-').map(Number);

      const utcMidnight = new Date(Date.UTC(year, month - 1, day));

      const nyDateString = new Date(utcMidnight.toLocaleString("en-US", { timeZone: "America/New_York" }));
      const offsetDiff = utcMidnight.getTime() - nyDateString.getTime(); // Returns offset in ms

      // Calculate 16:00 (4 PM) UTC
      const utc1600 = new Date(Date.UTC(year, month - 1, day, 16, 0, 0));
      // Apply offset to shift 16:00 UTC to 16:00 ET
      const targetTimeMs = utc1600.getTime() + offsetDiff;

      const timestamp = Math.floor(targetTimeMs / 1000);

      return {
        ticker: data.ticker ?? ticker,
        nav: data.nav,
        dt: data.dt,
        timestamp,
      }
    } catch (error: unknown) {
      const isLastRetry = i === retries - 1
      const msg = error instanceof Error ? error.message : String(error)
      console.warn(
        `[WisdomTree] Attempt ${i + 1} for ${ticker} failed: ${msg} ${isLastRetry.toString()}`,
      )

      if (isLastRetry) throw error

      const jitter = Math.random() * 1000
      await sleep(Math.pow(2, i) * 1000 + jitter)
    }
  }

  throw new Error(`Failed to fetch data for ${ticker} after ${retries} attempts`)
}
