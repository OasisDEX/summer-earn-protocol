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
export async function fetchOracleData(ticker: string, retries = 3): Promise<OracleData> {
  const url = `https://dataspanapi.wisdomtree.com/funddetails/nav/?ticker=${ticker}`

  const headers = {
    'User-Agent':
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    Accept: 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
    Origin: 'https://www.wisdomtree.com',
    Referer: 'https://www.wisdomtree.com/',
    'Cache-Control': 'no-cache',
    Pragma: 'no-cache',
    'sec-ch-ua': '"Not A(Bit:Brand";v="99", "Google Chrome";v="121", "Chromium";v="121"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"macOS"',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'same-site',
  }

  for (let i = 0; i < retries; i++) {
    try {
      const response = await fetch(url, {
        headers,
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

      const date = new Date(data.dt)
      const timestamp = Math.floor(date.getTime() / 1000)

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
