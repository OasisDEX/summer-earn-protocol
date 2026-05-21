import type { Address } from 'viem'

import type { ChainId } from '@/types/chain'

export type PriceRange = '7d' | '30d' | '90d' | 'all'

export const RANGE_TO_SECONDS: Record<Exclude<PriceRange, 'all'>, number> = {
  '7d': 7 * 24 * 60 * 60,
  '30d': 30 * 24 * 60 * 60,
  '90d': 90 * 24 * 60 * 60,
}

export interface PricePoint {
  // Milliseconds since epoch.
  t: number
  // USD value (or whatever the feed's quote currency is — typically USD).
  p: number
}

export type PriceSource = 'chainlink-subgraph' | 'defillama' | 'mixed' | 'cache'
export type PriceBasis = 'chainlink-feed' | 'off-chain-aggregate' | 'mixed'

export interface PriceSeries {
  chainId: ChainId
  // Lowercased ERC-20 address.
  token: Address
  // Lowercased feed address that produced the points, if applicable.
  feed?: Address
  range: PriceRange
  points: PricePoint[]
  // Inclusive [startMs, endMs] regions where no points are available. The
  // chart breaks the line across these to avoid drawing straight-line lies.
  gaps: Array<[number, number]>
  source: PriceSource
  basis: PriceBasis
  // Milliseconds since epoch — earliest point the underlying indexer can
  // ever serve for this token (e.g. when a dynamic feed template was
  // registered). Lets the chart label "price data begins {date}" left of
  // this boundary.
  dataStartsAt?: number
}

export interface PriceFeedFetchArgs {
  chainId: ChainId
  token: Address
  // Optional pre-resolved feed address. Sources that don't use Chainlink
  // ignore it.
  feed?: Address
  range: PriceRange
}

// All sources return `null` when they explicitly have no knowledge of the
// token. Throwing is reserved for transport / parse errors.
export interface PriceFeedSource {
  readonly name: string
  fetchSeries(args: PriceFeedFetchArgs): Promise<PriceSeries | null>
}
