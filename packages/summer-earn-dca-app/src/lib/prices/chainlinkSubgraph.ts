import { lookupFeedForAsset } from '@/config/addresses'
import { gqlFetch } from '@/lib/subgraph/client'
import { PRICE_HISTORY } from '@/lib/subgraph/queries'
import type { SubgraphPriceFeed, SubgraphPriceRound } from '@/lib/subgraph/types'

import { GAP_MULTIPLIER, heartbeatFor } from './heartbeats'
import { type PriceFeedSource, type PricePoint, type PriceSeries,RANGE_TO_SECONDS } from './types'

interface PriceHistoryResponse {
  priceFeed: SubgraphPriceFeed | null
  priceRounds: SubgraphPriceRound[]
}

const PAGE = 1000

export function createChainlinkSubgraphSource(): PriceFeedSource {
  return {
    name: 'chainlink-subgraph',
    async fetchSeries({ chainId, token, feed, range }) {
      const feedAddress = feed ?? lookupFeedForAsset(chainId, token)
      if (!feedAddress) return null

      // `priceFeed.id` is stored as `Bytes` (lowercased hex).
      const feedKey = feedAddress.toLowerCase()
      const nowSec = Math.floor(Date.now() / 1000)
      const fromSec =
        range === 'all' ? 0 : nowSec - RANGE_TO_SECONDS[range]

      // Page until the page is short — Goldsky caps to 1000 per page.
      let skip = 0
      const rounds: SubgraphPriceRound[] = []
      let feedMeta: SubgraphPriceFeed | null = null
       
      while (true) {
        const data = await gqlFetch<PriceHistoryResponse>(chainId, PRICE_HISTORY, {
          feed: feedKey,
          from: fromSec.toString(),
          first: PAGE,
          skip,
        })
        if (feedMeta == null) feedMeta = data.priceFeed
        rounds.push(...data.priceRounds)
        if (data.priceRounds.length < PAGE) break
        skip += PAGE
      }

      // Feed never indexed by this subgraph deployment.
      if (feedMeta == null && rounds.length === 0) return null

      const decimals = feedMeta?.decimals ?? 8
      const heartbeat = heartbeatFor(chainId, feedAddress)
      const points: PricePoint[] = rounds.map((r) => ({
        t: Number(r.updatedAt) * 1000,
        p: Number(r.answer) / Math.pow(10, decimals),
      }))

      // Gaps: any neighbour pair with delta > GAP_MULTIPLIER * heartbeat seconds.
      const gaps: Array<[number, number]> = []
      const heartbeatMs = heartbeat * 1000
      for (let i = 1; i < points.length; i++) {
        const delta = points[i].t - points[i - 1].t
        if (delta > heartbeatMs * GAP_MULTIPLIER) {
          gaps.push([points[i - 1].t, points[i].t])
        }
      }

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
