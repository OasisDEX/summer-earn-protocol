'use client'

import { Skeleton } from './Skeleton'

interface StatCardProps {
  label: string
  value: string
  suffix?: string
  hint?: string
  highlight?: boolean
  loading?: boolean
}

export function StatCard({
  label,
  value,
  suffix,
  hint,
  highlight = false,
  loading = false,
}: StatCardProps) {
  return (
    <div className={`glass p-5 rounded-xl ${highlight ? 'border-primary/20 bg-primary/5' : ''}`}>
      <p
        className={`text-xs font-semibold uppercase tracking-wider mb-1 ${
          highlight ? 'text-primary' : 'text-on-surface-variant'
        }`}
      >
        {label}
      </p>
      {loading ? (
        <Skeleton className="h-8 w-24" />
      ) : (
        <h3 className="text-2xl font-bold text-on-surface tabular-nums truncate" title={value}>
          {value}
          {suffix && <span className="text-lg font-normal text-on-surface-variant"> {suffix}</span>}
        </h3>
      )}
      {hint && <p className="mt-1 text-xs text-on-surface-variant/80">{hint}</p>}
    </div>
  )
}
