'use client'

import { type ComponentPropsWithoutRef, useState } from 'react'

import { formatAddress } from '@/utils/address'

interface AddressDisplayProps extends ComponentPropsWithoutRef<'span'> {
  value?: string | null
  /** visible hex chars on each side (default 4 → 0x1234…abcd) */
  chars?: number
  /** render the full value (mono, break-all) for detail panes */
  full?: boolean
  /** copy-to-clipboard affordance — enable only where one already exists */
  copy?: boolean
  /** block-explorer URL — pass only where a link is already rendered today */
  href?: string
}

export function AddressDisplay({
  value,
  chars = 4,
  full = false,
  copy = false,
  href,
  className = '',
  ...rest
}: AddressDisplayProps) {
  const [copied, setCopied] = useState(false)

  const text = full ? value ?? '—' : formatAddress(value, chars)
  const mono = `font-mono tabular-nums ${full ? 'break-all' : 'whitespace-nowrap'}`

  const handleCopy = () => {
    if (!value) return
    navigator.clipboard?.writeText(value).then(() => {
      setCopied(true)
      setTimeout(() => setCopied(false), 1500)
    })
  }

  const inner = href ? (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className="hover:text-primary transition-colors underline-offset-2 hover:underline"
    >
      {text}
    </a>
  ) : (
    text
  )

  return (
    <span
      title={value ?? undefined}
      className={`inline-flex items-baseline gap-1.5 ${mono} ${className}`}
      {...rest}
    >
      {inner}
      {copy && value && (
        <button
          type="button"
          onClick={handleCopy}
          aria-label="Copy address"
          className="self-center text-on-surface-variant hover:text-on-surface transition-colors"
        >
          {copied ? (
            <svg width="12" height="12" viewBox="0 0 16 16" fill="none" aria-hidden="true">
              <path
                d="M3 8.5L6.5 12L13 5"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          ) : (
            <svg width="12" height="12" viewBox="0 0 16 16" fill="none" aria-hidden="true">
              <rect
                x="5.5"
                y="5.5"
                width="8"
                height="8"
                rx="1.5"
                stroke="currentColor"
                strokeWidth="1.2"
              />
              <path
                d="M10.5 5.5V4a1.5 1.5 0 0 0-1.5-1.5H4A1.5 1.5 0 0 0 2.5 4v5A1.5 1.5 0 0 0 4 10.5h1.5"
                stroke="currentColor"
                strokeWidth="1.2"
              />
            </svg>
          )}
        </button>
      )}
    </span>
  )
}
