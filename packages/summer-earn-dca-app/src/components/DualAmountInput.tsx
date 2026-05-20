'use client'

import { useEffect, useMemo, useState } from 'react'
import type { Address } from 'viem'

import { Field, TextInput } from '@/components/ui/Field'
import { useSourceVaultPreview } from '@/hooks/useSourceVaultPreview'
import { formatDecimalOutput, parseDecimalInput } from '@/lib/format'
import type { ChainId } from '@/types/chain'

interface DualAmountInputProps {
  chainId: ChainId
  sourceVault: Address | undefined
  underlyingDecimals: number
  underlyingSymbol: string
  shareDecimals: number
  shareSymbol: string
  /** Persisted value (shares). */
  shares: bigint
  onChange: (shares: bigint) => void
}

// Dual-bound input — user can type either underlying assets or vault shares;
// the FE reads convertToShares / convertToAssets to keep both sides in sync.
// Shares are what the contract stores in StrategyConfig.tradeAmount, so the
// caller persists `shares` (not the underlying).
export function DualAmountInput({
  chainId,
  sourceVault,
  underlyingDecimals,
  underlyingSymbol,
  shareDecimals,
  shareSymbol,
  shares,
  onChange,
}: DualAmountInputProps) {
  const [activeField, setActiveField] = useState<'assets' | 'shares'>('shares')
  const [assetsInput, setAssetsInput] = useState('')
  const [sharesInput, setSharesInput] = useState(() =>
    shares === 0n ? '' : formatDecimalOutput(shares, shareDecimals, shareDecimals),
  )

  const assetsBig = activeField === 'assets' ? parseDecimalInput(assetsInput, underlyingDecimals) : 0n
  const sharesBig = activeField === 'shares' ? parseDecimalInput(sharesInput, shareDecimals) : 0n

  const preview = useSourceVaultPreview({
    chainId,
    sourceVault,
    assets: activeField === 'assets' ? assetsBig : undefined,
    shares: activeField === 'shares' ? sharesBig : undefined,
  })

  // When the user types underlying assets, we publish convertToShares(assets) → shares.
  // When the user types shares, we publish that share value directly.
  useEffect(() => {
    if (activeField === 'shares') {
      onChange(sharesBig)
    } else if (preview.data) {
      onChange(preview.data.shares)
    }
  }, [activeField, sharesBig, preview.data, onChange])

  const mirroredShares = useMemo(() => {
    if (activeField !== 'assets') return ''
    if (!preview.data) return ''
    return formatDecimalOutput(preview.data.shares, shareDecimals, 6)
  }, [activeField, preview.data, shareDecimals])

  const mirroredAssets = useMemo(() => {
    if (activeField !== 'shares') return ''
    if (!preview.data) return ''
    return formatDecimalOutput(preview.data.assetsFromShares, underlyingDecimals, 6)
  }, [activeField, preview.data, underlyingDecimals])

  return (
    <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
      <Field
        label={`Underlying (${underlyingSymbol})`}
        hint={
          activeField === 'shares' && mirroredAssets
            ? `≈ ${mirroredAssets} ${underlyingSymbol} (read-only)`
            : undefined
        }
      >
        <TextInput
          inputMode="decimal"
          placeholder="0.0"
          value={assetsInput}
          onFocus={() => setActiveField('assets')}
          onChange={(e) => {
            setActiveField('assets')
            setAssetsInput(e.target.value)
          }}
        />
      </Field>
      <Field
        label={`Shares (${shareSymbol})`}
        hint={
          activeField === 'assets' && mirroredShares
            ? `≈ ${mirroredShares} ${shareSymbol} — stored in tradeAmount`
            : 'Persisted in StrategyConfig.tradeAmount'
        }
      >
        <TextInput
          inputMode="decimal"
          placeholder="0.0"
          value={sharesInput}
          onFocus={() => setActiveField('shares')}
          onChange={(e) => {
            setActiveField('shares')
            setSharesInput(e.target.value)
          }}
        />
      </Field>
    </div>
  )
}
