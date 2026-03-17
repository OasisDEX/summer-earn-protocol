import { chromium, Browser, BrowserContext } from 'playwright'

/**
 * Shared base utility for fetching data from WisdomTree DataSpan API.
 * Handles Playwright initialization, Cloudflare bypass, and retries.
 */

const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms))

export async function fetchWithPlaywright<T>(url: string, retries = 3): Promise<T> {
  let browser: Browser | null = null
  let context: BrowserContext | null = null

  for (let i = 0; i < retries; i++) {
    browser = await chromium.launch({ headless: true })
    context = await browser.newContext({
      userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    })
    const page = await context.newPage()

    try {
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 })
      const content = await page.innerText('body')

      if (content.includes('Cloudflare') || content.includes('Attention Required')) {
        throw new Error('Cloudflare Block detected.')
      }

      const data = JSON.parse(content) as T
      return data
    } catch (error: any) {
      const isLastRetry = i === retries - 1
      if (isLastRetry) throw error

      console.warn(`[Playwright] Attempt ${i + 1} failed: ${error.message}. Retrying...`)
      await sleep(Math.pow(2, i) * 1000)
    } finally {
      if (browser) await browser.close()
    }
  }

  throw new Error(`Failed to fetch from ${url} after ${retries} attempts`)
}
