'use client'

import type { Address } from 'viem'

import { useFeedPrice } from '@/hooks/useFeedPrice'
import { formatFeedPrice, formatUnixDate } from '@/lib/format'
import type { ChainId } from '@/types/chain'

interface Props {
  chainId: ChainId
  feed: Address | undefined
  /** Optional label like "ETH" — rendered after the price as "ETH/USD". */
  symbol?: string
  className?: string
  compact?: boolean
}

// Renders the latest Chainlink price for a feed, polled per block.
// Falls back to a discreet placeholder while loading or when no feed picked.
export function FeedPriceDisplay({ chainId, feed, symbol, className, compact }: Props) {
  const { data, isLoading, isError } = useFeedPrice(chainId, feed)

  if (!feed) {
    return <span className={['text-surface-500', className ?? ''].join(' ')}>—</span>
  }
  if (isLoading || !data) {
    return <span className={['text-surface-500', className ?? ''].join(' ')}>loading…</span>
  }
  if (isError) {
    return <span className={['text-danger', className ?? ''].join(' ')}>price error</span>
  }

  const priceStr = formatFeedPrice(data.answer, data.decimals, 2)
  const ageSec = Math.max(0, Math.floor(Date.now() / 1000) - Number(data.updatedAt))

  if (compact) {
    return (
      <span className={['text-surface-100', className ?? ''].join(' ')}>
        ${priceStr}
        {symbol ? <span className="text-surface-400"> {symbol}/USD</span> : null}
      </span>
    )
  }

  return (
    <span
      className={['inline-flex flex-col leading-tight', className ?? ''].join(' ')}
      title={`Last updated: ${formatUnixDate(data.updatedAt)} (${ageSec}s ago)`}
    >
      <span className="text-surface-100">
        ${priceStr}
        {symbol ? <span className="text-surface-400"> {symbol}/USD</span> : null}
      </span>
      <span className="text-[10px] text-surface-500">live · {ageSec}s old</span>
    </span>
  )
}
