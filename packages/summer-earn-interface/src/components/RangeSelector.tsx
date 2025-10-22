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
  { label: '365d', value: '365d' },
]

export const RangeSelector: React.FC<RangeSelectorProps> = ({ value, onChange, className }) => {
  return (
    <div className={className}>
      <div className="inline-flex rounded-md shadow-sm overflow-hidden border border-gray-700">
        {OPTIONS.map((option) => (
          <button
            key={option.value}
            type="button"
            onClick={() => onChange(option.value)}
            className={
              `px-3 py-1.5 text-sm transition-colors ${
                value === option.value
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-800 text-gray-300 hover:bg-gray-700'
              }` +
              (option.value !== OPTIONS[OPTIONS.length - 1].value
                ? ' border-r border-gray-700'
                : '')
            }
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
