'use client'

import { useState } from 'react'
import { Check, Copy, ExternalLink } from 'lucide-react'
import { explorerAddressUrl, shortAddress } from '@/lib/explorer'
import { useChainId } from './graph-context'

export function AddressChip({ address }: { address: string }) {
  const chainId = useChainId()
  const [copied, setCopied] = useState(false)
  const url = explorerAddressUrl(chainId, address)

  const copy = async (e: React.MouseEvent) => {
    e.stopPropagation()
    try {
      await navigator.clipboard.writeText(address)
      setCopied(true)
      setTimeout(() => setCopied(false), 1200)
    } catch {
      /* clipboard unavailable */
    }
  }

  return (
    <span className="inline-flex items-center gap-1 rounded bg-surface-container-highest px-1.5 py-0.5 font-mono text-[10px] text-on-surface-variant">
      {shortAddress(address)}
      <button onClick={copy} className="text-outline hover:text-on-surface" title="Copy address">
        {copied ? <Check size={11} /> : <Copy size={11} />}
      </button>
      {url && (
        <a
          href={url}
          target="_blank"
          rel="noreferrer"
          onClick={(e) => e.stopPropagation()}
          className="text-outline hover:text-primary"
          title="View on explorer"
        >
          <ExternalLink size={11} />
        </a>
      )}
    </span>
  )
}
