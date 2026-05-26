import { time } from '@/lib/perf'

import {
  type PriceFeedFetchArgs,
  type PriceFeedSource,
  type PricePoint,
  type PriceSeries,
  RANGE_TO_SECONDS,
} from './types'

// Threshold for merging a partial primary response with a fallback. If gaps
// cover more than this fraction of the requested range, we treat the primary
// as partial and try to fill from the fallback.
const PARTIAL_GAP_FRACTION = 0.25

export interface CompositePriceClient {
  fetchSeries(args: PriceFeedFetchArgs): Promise<PriceSeries | null>
}

export function createCompositePriceClient(sources: PriceFeedSource[]): CompositePriceClient {
  if (sources.length === 0) {
    throw new Error('createCompositePriceClient requires at least one source')
  }

  return {
    async fetchSeries(args) {
      let primary: PriceSeries | null = null
      let primaryError: unknown = null

      try {
        primary = await time(`price-source:${sources[0].name}`, () => sources[0].fetchSeries(args))
      } catch (err) {
        primaryError = err
        primary = null
      }

      // Primary OK and not visibly degraded — return as-is.
      if (primary && !isDegraded(primary, args)) {
        return primary
      }

      // Try fallbacks in order.
      for (let i = 1; i < sources.length; i++) {
        let fallback: PriceSeries | null = null
        try {
          fallback = await time(`price-source:${sources[i].name}`, () =>
            sources[i].fetchSeries(args),
          )
        } catch {
          continue
        }
        if (!fallback) continue

        if (primary && primary.points.length > 0) {
          // Merge primary points (Chainlink) on top of fallback (DeFiLlama)
          // and mark basis as mixed so the chart can show a small note.
          return mergeSeries(primary, fallback)
        }
        return fallback
      }

      if (primary) return primary
      if (primaryError) throw primaryError
      return null
    },
  }
}

function isDegraded(series: PriceSeries, args: PriceFeedFetchArgs): boolean {
  if (series.points.length === 0) return true
  if (args.range === 'all') return false
  const span = RANGE_TO_SECONDS[args.range] * 1000
  const gapMs = series.gaps.reduce((sum, [a, b]) => sum + (b - a), 0)
  return gapMs / span > PARTIAL_GAP_FRACTION
}

function mergeSeries(primary: PriceSeries, fallback: PriceSeries): PriceSeries {
  // Primary points win at any timestamp; fallback fills the timeline only
  // outside the primary's covered window.
  const primaryMin = primary.points[0]?.t ?? Infinity
  const primaryMax = primary.points[primary.points.length - 1]?.t ?? -Infinity

  const merged: PricePoint[] = [...primary.points]
  for (const fp of fallback.points) {
    if (fp.t < primaryMin || fp.t > primaryMax) {
      merged.push(fp)
      continue
    }
    // Inside primary window — only fill if a primary gap covers this point.
    const inGap = primary.gaps.some(([a, b]) => fp.t >= a && fp.t <= b)
    if (inGap) merged.push(fp)
  }
  merged.sort((a, b) => a.t - b.t)

  return {
    ...primary,
    points: merged,
    gaps: [], // gaps are filled by the merge
    source: 'mixed',
    basis: 'mixed',
  }
}
