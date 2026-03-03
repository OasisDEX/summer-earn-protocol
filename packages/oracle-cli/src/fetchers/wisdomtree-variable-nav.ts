import { chromium } from 'playwright'

/**
 * WisdomTree Variable NAV fetcher.
 * Fetches NAV data from the WisdomTree DataSpan API using Playwright to bypass Cloudflare.
 */

export interface OracleData {
  ticker: string
  nav: number
  dt: string // YYYY-MM-DD
  timestamp: number // Unix timestamp of the data
}

const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms))

export async function fetchOracleData(ticker: string, retries = 3): Promise<OracleData> {
  const url = `https://dataspanapi.wisdomtree.com/funddetails/nav/?ticker=${ticker}`

  for (let i = 0; i < retries; i++) {
    const browser = await chromium.launch({ headless: true })
    const context = await browser.newContext({
      userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    })
    const page = await context.newPage()

    try {
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 15000 })

      const content = await page.innerText('body')

      if (content.includes('Cloudflare') || content.includes('Attention Required')) {
        throw new Error('Cloudflare Block (403 Forbidden).')
      }

      const data = JSON.parse(content) as { ticker?: string; nav?: number; dt?: string }

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

      await browser.close()

      return {
        ticker: data.ticker ?? ticker,
        nav: data.nav,
        dt: data.dt,
        timestamp,
      }
    } catch (error: unknown) {
      await browser.close()

      const isLastRetry = i === retries - 1
      const msg = error instanceof Error ? error.message : String(error)
      console.warn(`[WisdomTree] Attempt ${i + 1} for ${ticker} failed: ${msg}`)

      if (isLastRetry) throw error

      await sleep(Math.pow(2, i) * 1000)
    }
  }

  throw new Error(`Failed to fetch data for ${ticker} after ${retries} attempts`)
}
