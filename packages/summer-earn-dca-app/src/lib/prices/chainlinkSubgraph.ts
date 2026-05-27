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

// 1 week ≈ 504 rounds for ETH/USD on Base — under The Graph's 1000/page cap.
// Sparser feeds fit easily. A higher-frequency feed would silently truncate.
const WINDOW_SECONDS = WEEK_SECONDS

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

// Cap the unbounded `all` range so the parallel fan-out stays bounded.
const ALL_RANGE_SECONDS = 365 * DAY_SECONDS

export function createChainlinkSubgraphSource(): PriceFeedSource {
  return {
    name: 'chainlink-subgraph',
    async fetchSeries({ chainId, token, feed, range }) {
      const feedAddress = feed ?? lookupFeedForAsset(chainId, token)
      if (!feedAddress) return null

      // priceFeed.id is stored as lowercased Bytes hex.
      const feedKey = feedAddress.toLowerCase()
      const bucketSec = bucketSecondsFor(range)

      // Snap to bucket boundaries so the cached payload is byte-identical
      // for every request in the same bucket period.
      const nowSec = Math.floor(Date.now() / 1000)
      const nowAligned = Math.floor(nowSec / bucketSec) * bucketSec
      const totalSeconds = range === 'all' ? ALL_RANGE_SECONDS : RANGE_TO_SECONDS[range]
      const fromAligned = Math.floor((nowAligned - totalSeconds) / bucketSec) * bucketSec

      const windows: Array<[number, number]> = []
      for (let s = fromAligned; s < nowAligned; s += WINDOW_SECONDS) {
        const e = Math.min(s + WINDOW_SECONDS, nowAligned)
        windows.push([s, e])
      }
      if (windows.length === 0) windows.push([fromAligned, nowAligned])

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

      const rounds: WindowRound[] = []
      for (const r of responses) rounds.push(...r.priceRounds)

      // For each bucket boundary, emit the LAST round whose updatedAt is
      // ≤ the boundary — carries the active price forward through buckets
      // where the feed didn't tick.
      const points: PricePoint[] = []
      let cursor = 0
      let activeAnswer: number | null = null
      for (let bucketStart = fromAligned; bucketStart <= nowAligned; bucketStart += bucketSec) {
        while (cursor < rounds.length && Number(rounds[cursor].updatedAt) <= bucketStart) {
          activeAnswer = Number(rounds[cursor].answer) / Math.pow(10, decimals)
          cursor++
        }
        if (activeAnswer != null) {
          points.push({ t: bucketStart * 1000, p: activeAnswer })
        }
      }

      if (feedMeta == null && points.length === 0) return null

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
