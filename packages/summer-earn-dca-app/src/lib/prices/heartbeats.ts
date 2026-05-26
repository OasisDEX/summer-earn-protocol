import { type Address, getAddress } from 'viem'
import { base } from 'wagmi/chains'

import type { ChainId } from '@/types/chain'

// Chainlink publishes a heartbeat per feed on data.chain.link. The number is
// the maximum interval between updates if the price doesn't move; deviation
// triggers can update sooner. We use this to detect "gaps" in the indexed
// `PriceRound` stream that exceed `gapMultiplier * heartbeat` and break the
// chart line across them rather than drawing straight-line lies between
// distant points. With the event-driven subgraph (every `AnswerUpdated`
// becomes a `PriceRound`) the only legitimate gaps are real downtime —
// hence `GAP_MULTIPLIER = 4` so we don't draw spurious gaps at the natural
// edges of Chainlink heartbeat coalescing.
export const HEARTBEAT_BY_FEED: Record<ChainId, Record<string, number>> = {
  [base.id]: {
    // ETH/USD — Base proxy, 20 min heartbeat
    [getAddress('0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70').toLowerCase()]: 1200,
    // USDC/USD — Base proxy, 24h heartbeat
    [getAddress('0x7e860098F58bBFC8648a4311b374B1D669a2bc6B').toLowerCase()]: 86_400,
  },
}

export const DEFAULT_HEARTBEAT_SECONDS = 3600
export const GAP_MULTIPLIER = 4

export function heartbeatFor(chainId: ChainId, feed: Address | undefined): number {
  if (!feed) return DEFAULT_HEARTBEAT_SECONDS
  return HEARTBEAT_BY_FEED[chainId]?.[feed.toLowerCase()] ?? DEFAULT_HEARTBEAT_SECONDS
}
