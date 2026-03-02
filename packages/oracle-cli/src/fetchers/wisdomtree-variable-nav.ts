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
    // Uruchamiamy przeglądarkę w tle (headless)
    const browser = await chromium.launch({ headless: true })
    const context = await browser.newContext({
      userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    })
    const page = await context.newPage()

    try {
      // Wchodzimy pod adres URL - Playwright automatycznie rozwiąże JS Challenge od Cloudflare
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 15000 })

      // Wyciągamy czysty tekst z tagu <body> (ponieważ API zwraca po prostu tekst JSON na stronie)
      const content = await page.innerText('body')

      if (content.includes('Cloudflare') || content.includes('Attention Required')) {
        throw new Error('Cloudflare Block (403 Forbidden).')
      }

      const data = JSON.parse(content) as { ticker?: string; nav?: number; dt?: string }

      if (!data || !data.nav || !data.dt) {
        throw new Error('Malformed API response: Missing NAV or Date')
      }

      const date = new Date(data.dt)
      const timestamp = Math.floor(date.getTime() / 1000)

      await browser.close()

      return {
        ticker: data.ticker ?? ticker,
        nav: data.nav,
        dt: data.dt,
        timestamp,
      }
    } catch (error: unknown) {
      await browser.close() // Upewnij się, że zamykamy przeglądarkę w przypadku błędu

      const isLastRetry = i === retries - 1
      const msg = error instanceof Error ? error.message : String(error)
      console.warn(`[WisdomTree] Attempt ${i + 1} for ${ticker} failed: ${msg}`)

      if (isLastRetry) throw error

      await sleep(Math.pow(2, i) * 1000)
    }
  }

  throw new Error(`Failed to fetch data for ${ticker} after ${retries} attempts`)
}
