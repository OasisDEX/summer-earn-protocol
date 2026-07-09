'use client'

import { useState } from 'react'
import type { Address } from 'viem'
import { useAccount } from 'wagmi'

import { GlassCard } from '../../../components/GlassCard'
import { AddressDisplay } from '../../../components/ui'
import { useOAppAdmin } from '../hooks/useOAppAdmin'
import type { ChainName, OAppKind } from '../lib/types'

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

function isZeroAddr(a: string | null | undefined): boolean {
  return !a || a.toLowerCase() === ZERO_ADDRESS
}

function eqCI(a: string | null | undefined, b: string | null | undefined): boolean {
  if (!a || !b) return false
  return a.toLowerCase() === b.toLowerCase()
}

function CopyButton({ value }: { value: string }) {
  const [copied, setCopied] = useState(false)
  return (
    <button
      type="button"
      onClick={(e) => {
        e.stopPropagation()
        void navigator.clipboard.writeText(value).then(() => {
          setCopied(true)
          setTimeout(() => setCopied(false), 1000)
        })
      }}
      className="text-xs px-2 py-0.5 rounded border border-white/10 bg-white/5 text-on-surface-variant hover:bg-white/10 transition-colors"
    >
      {copied ? 'Copied' : 'Copy'}
    </button>
  )
}

interface Props {
  sourceChain: ChainName
  oApp: OAppKind
}

export function AdminCard({ sourceChain, oApp }: Props) {
  const { data: admin, isLoading } = useOAppAdmin(sourceChain, oApp)
  const { address: wallet } = useAccount()

  const owner = admin?.owner ?? null
  const delegate = admin?.delegate ?? null

  const ownerMatchesWallet = owner && wallet && eqCI(owner, wallet)
  const delegateMatchesWallet = delegate && wallet && eqCI(delegate, wallet)
  const delegateIsZero = isZeroAddr(delegate)
  const delegateEqualsOwner =
    !!owner && !!delegate && !isZeroAddr(owner) && !delegateIsZero && eqCI(owner, delegate)

  return (
    <GlassCard>
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-semibold text-on-surface uppercase tracking-wider">
          OApp Admin
        </h3>
        <span className="text-xs text-on-surface-variant">
          {sourceChain} · {oApp}
        </span>
      </div>

      <div className="space-y-3">
        <AdminRow
          label="OApp Owner"
          address={owner}
          isLoading={isLoading}
          chipLabel={ownerMatchesWallet ? 'matches your wallet' : null}
          chipClass="bg-success/15 text-success border-success/30"
          dimWhenMissing
        />
        <AdminRow
          label="Delegate"
          address={delegate}
          isLoading={isLoading}
          chipLabel={
            delegateMatchesWallet
              ? 'matches your wallet'
              : delegateEqualsOwner
                ? 'equals owner — see tip'
                : null
          }
          chipClass={
            delegateMatchesWallet
              ? 'bg-success/15 text-success border-success/30'
              : 'bg-warning/15 text-warning border-warning/30'
          }
          fallbackText={delegateIsZero && !isLoading ? '(unset / zero address)' : undefined}
          fallbackClass="text-warning"
        />

        {delegateEqualsOwner && (
          <div className="text-xs px-3 py-2 rounded border border-primary/20 bg-primary/5 text-on-surface-variant">
            <span className="font-semibold text-primary">Tip: </span>
            Delegate equals owner — set a dedicated operations Safe via{' '}
            <code className="bg-white/5 px-1 rounded">Edit route</code> to update DVN configuration
            without governance proposals.
          </div>
        )}
      </div>
    </GlassCard>
  )
}

function AdminRow({
  label,
  address,
  isLoading,
  chipLabel,
  chipClass,
  dimWhenMissing,
  fallbackText,
  fallbackClass,
}: {
  label: string
  address: Address | null
  isLoading: boolean
  chipLabel: string | null
  chipClass: string
  dimWhenMissing?: boolean
  fallbackText?: string
  fallbackClass?: string
}) {
  const showFallback = !isLoading && !address
  return (
    <div className="grid grid-cols-[110px,1fr] items-center gap-3">
      <span className="text-xs uppercase tracking-wider text-on-surface-variant">{label}</span>
      <div className="flex items-center gap-2 flex-wrap">
        {isLoading ? (
          <span className="text-on-surface-variant text-xs">Loading…</span>
        ) : address ? (
          <>
            <AddressDisplay value={address} className="text-sm text-on-surface" />
            <CopyButton value={address} />
            {chipLabel && (
              <span
                className={`inline-block px-2 py-0.5 text-xs font-semibold rounded border ${chipClass}`}
              >
                {chipLabel}
              </span>
            )}
          </>
        ) : (
          <span
            className={`font-mono text-sm ${
              fallbackClass ??
              (dimWhenMissing ? 'text-on-surface-variant' : 'text-on-surface-variant/80')
            }`}
          >
            {fallbackText ?? '—'}
          </span>
        )}
        {!isLoading && address && showFallback && null}
      </div>
    </div>
  )
}
