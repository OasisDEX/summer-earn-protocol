import { createChainlinkSubgraphSource } from './chainlinkSubgraph'
import { type CompositePriceClient,createCompositePriceClient } from './composite'
import { createDefiLlamaSource } from './defillama'

export type {
  PriceBasis,
  PriceFeedFetchArgs,
  PriceFeedSource,
  PricePoint,
  PriceRange,
  PriceSeries,
  PriceSource,
} from './types'
export { RANGE_TO_SECONDS } from './types'

// Singleton client used by the server route handler. Primary = Chainlink
// (faithful to what the contract checks); fallback = DeFiLlama (broad
// coverage for tokens we haven't started indexing yet).
let _client: CompositePriceClient | null = null

export function getPriceClient(): CompositePriceClient {
  if (_client == null) {
    _client = createCompositePriceClient([
      createChainlinkSubgraphSource(),
      createDefiLlamaSource(),
    ])
  }
  return _client
}
