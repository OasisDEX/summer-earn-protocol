import { lookupFeedForAsset } from '@/config/addresses'
import { gqlFetch } from '@/lib/subgraph/client'
import { PRICE_WINDOW, PRICE_WINDOW_FIRST } from '@/lib/subgraph/queries'
import type { SubgraphPriceFeed } from '@/lib/subgraph/types'

import {
  type PriceFeedSource,
  type PricePoint,
  type PriceRange,
  type PriceSeries,
  RANGE_TO_SECONDS,
} from './types'

interface WindowRound {
  answer: string
  updatedAt: string
}

interface WindowResponseFirst {
  priceFeed: SubgraphPriceFeed | null
  priceRounds: WindowRound[]
}

interface WindowResponse {
  priceRounds: WindowRound[]
}

const HOUR_SECONDS = 3600
const DAY_SECONDS = 86_400
const WEEK_SECONDS = 7 * DAY_SECONDS

// Window size for parallel fetches. ETH/USD on Base updates ~every 20min,
// so 1 week ≈ 504 rounds — comfortably below The Graph's 1000/page cap.
// Sparser feeds fit even more easily. If a window over-flows we'd silently
// drop the tail; revisit if we ever wire in a high-frequency feed.
const WINDOW_SECONDS = WEEK_SECONDS

// Bucket size for the final downsampled series. Hourly is the natural
// granularity for a daily-DCA chart; widen for longer ranges so the cached
// payload stays ≤ ~1000 points and the cache key is more share-friendly.
function bucketSecondsFor(range: PriceRange): number {
  switch (range) {
    case '7d':
      return HOUR_SECONDS
    case '30d':
      return HOUR_SECONDS
    case '90d':
      return HOUR_SECONDS * 3
    case 'all':
      return DAY_SECONDS
  }
}

// `all` doesn't have a bounded window — cap lookback so the parallel
// fan-out stays reasonable. ~1 year of weekly windows = 52 parallel calls.
const ALL_RANGE_SECONDS = 365 * DAY_SECONDS

export function createChainlinkSubgraphSource(): PriceFeedSource {
  return {
    name: 'chainlink-subgraph',
    async fetchSeries({ chainId, token, feed, range }) {
      const feedAddress = feed ?? lookupFeedForAsset(chainId, token)
      if (!feedAddress) return null

      // `priceFeed.id` is stored as `Bytes` (lowercased hex).
      const feedKey = feedAddress.toLowerCase()
      const bucketSec = bucketSecondsFor(range)

      // Snap both ends of the window to bucket boundaries so the cached
      // response is byte-identical for everyone in the same bucket period.
      // Combined with `cacheLife.revalidate = 1h` upstream, this means at
      // most one cold fetch per (feed, range) per hour globally per server.
      const nowSec = Math.floor(Date.now() / 1000)
      const nowAligned = Math.floor(nowSec / bucketSec) * bucketSec
      const totalSeconds = range === 'all' ? ALL_RANGE_SECONDS : RANGE_TO_SECONDS[range]
      const fromAligned = Math.floor((nowAligned - totalSeconds) / bucketSec) * bucketSec

      // Build [start, end) windows. The last one stops at `nowAligned` to
      // avoid double-fetching the current bucket.
      const windows: Array<[number, number]> = []
      for (let s = fromAligned; s < nowAligned; s += WINDOW_SECONDS) {
        const e = Math.min(s + WINDOW_SECONDS, nowAligned)
        windows.push([s, e])
      }
      if (windows.length === 0) windows.push([fromAligned, nowAligned])

      // Fire every window's query in parallel. Wall-clock cost is
      // max(window latency), not sum — typically ~300-500ms regardless of
      // how many weeks the range covers.
      const responses = await Promise.all(
        windows.map(([wFrom, wTo], idx) => {
          const variables = {
            feed: feedKey,
            from: String(wFrom),
            to: String(wTo),
          }
          if (idx === 0) {
            return gqlFetch<WindowResponseFirst>(chainId, PRICE_WINDOW_FIRST, variables)
          }
          return gqlFetch<WindowResponse>(chainId, PRICE_WINDOW, variables).then(
            (r) => ({ priceFeed: null, ...r }) as WindowResponseFirst,
          )
        }),
      )

      const feedMeta = responses[0]?.priceFeed ?? null
      const decimals = feedMeta?.decimals ?? 8

      // Merge all rounds in ascending order (windows are already disjoint
      // and ordered by their start, and the indexer returns each window
      // sorted by updatedAt asc).
      const rounds: WindowRound[] = []
      for (const r of responses) rounds.push(...r.priceRounds)

      // Downsample to one point per bucket: the LAST round whose
      // updatedAt falls in (bucket_start - bucketSec, bucket_start]. We
      // walk the rounds in ascending time order and update the active
      // round; for each bucket boundary, emit the active round if any.
      const points: PricePoint[] = []
      let cursor = 0
      let activeAnswer: number | null = null
      let activeUpdatedAt = 0
      for (let bucketStart = fromAligned; bucketStart <= nowAligned; bucketStart += bucketSec) {
        // Advance through all rounds at or before this bucket boundary.
        while (cursor < rounds.length && Number(rounds[cursor].updatedAt) <= bucketStart) {
          activeAnswer = Number(rounds[cursor].answer) / Math.pow(10, decimals)
          activeUpdatedAt = Number(rounds[cursor].updatedAt)
          cursor++
        }
        if (activeAnswer != null) {
          points.push({ t: bucketStart * 1000, p: activeAnswer })
        }
      }

      // Suppress unused-var warning while keeping the line for debugging.
      void activeUpdatedAt

      if (feedMeta == null && points.length === 0) return null

      // With bucket-aligned sampling every bucket has a price (we carry
      // forward the active round). True data starts after the feed's
      // firstSeenAt; the chart uses `dataStartsAt` to label that boundary
      // and skip empty pre-data buckets above.
      const gaps: Array<[number, number]> = []

      const dataStartsAt =
        feedMeta != null && feedMeta.firstSeenAt !== '0'
          ? Number(feedMeta.firstSeenAt) * 1000
          : undefined

      return {
        chainId,
        token: token.toLowerCase() as PriceSeries['token'],
        feed: feedAddress.toLowerCase() as PriceSeries['feed'],
        range,
        points,
        gaps,
        source: 'chainlink-subgraph',
        basis: 'chainlink-feed',
        dataStartsAt,
      }
    },
  }
}
