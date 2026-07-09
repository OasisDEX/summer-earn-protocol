import React from 'react'

export type RangeOption = '24h' | '7d' | '30d' | '90d' | '180d' | '365d'

interface RangeSelectorProps {
  value: RangeOption
  onChange: (value: RangeOption) => void
  className?: string
}

const OPTIONS: { label: string; value: RangeOption }[] = [
  { label: '24h', value: '24h' },
  { label: '7d', value: '7d' },
  { label: '30d', value: '30d' },
  { label: '90d', value: '90d' },
  { label: '180d', value: '180d' },
  { label: '1y', value: '365d' },
]

export const RangeSelector: React.FC<RangeSelectorProps> = ({ value, onChange, className }) => {
  return (
    <div className={className}>
      <div className="flex bg-surface-container-low p-1 rounded-lg border border-white/[0.06]">
        {OPTIONS.map((option) => (
          <button
            key={option.value}
            type="button"
            onClick={() => onChange(option.value)}
            className={`px-3 py-1.5 text-xs font-semibold rounded-md transition-all ${
              value === option.value
                ? 'bg-primary text-on-primary shadow-lg shadow-primary/20'
                : 'text-on-surface-variant hover:text-on-surface hover:bg-white/[0.04]'
            }`}
          >
            {option.label}
          </button>
        ))}
      </div>
    </div>
  )
}

export const getFromTimestampForRange = (range: RangeOption): number => {
  const nowSeconds = Math.floor(Date.now() / 1000)
  const day = 24 * 60 * 60
  const rangeToSeconds: Record<RangeOption, number> = {
    '24h': 1 * day,
    '7d': 7 * day,
    '30d': 30 * day,
    '90d': 90 * day,
    '180d': 180 * day,
    '365d': 365 * day,
  }
  return nowSeconds - rangeToSeconds[range]
}
