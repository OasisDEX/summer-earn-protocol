import { useId } from 'react'

import type { PricePoint } from '@/lib/prices'

interface MiniChartProps {
  data: PricePoint[]
  height?: number
  color?: string
  className?: string
}

// Card-sized area chart strip. No labels, no axes. Ignores gaps — at this
// scale they're not visible.
export function MiniChart({
  data,
  height = 56,
  color = 'var(--pink)',
  className = '',
}: MiniChartProps) {
  const id = useId().replace(/[:]/g, '')
  if (!data || data.length < 2) {
    return <div className={className} style={{ height }} aria-hidden />
  }
  const W = 320
  const H = height
  const ps = data.map((d) => d.p)
  const min = Math.min(...ps)
  const max = Math.max(...ps)
  const span = max - min || 1
  const t0 = data[0].t
  const t1 = data[data.length - 1].t
  const tSpan = t1 - t0 || 1

  const path = data
    .map((d, i) => {
      const x = ((d.t - t0) / tSpan) * W
      const y = H - ((d.p - min) / span) * (H - 8) - 4
      return `${i === 0 ? 'M' : 'L'} ${x.toFixed(1)} ${y.toFixed(1)}`
    })
    .join(' ')
  const area = `${path} L ${W} ${H} L 0 ${H} Z`
  const gradId = `mini-${id}`

  return (
    <svg
      width="100%"
      viewBox={`0 0 ${W} ${H}`}
      preserveAspectRatio="none"
      className={className}
      aria-hidden
    >
      <defs>
        <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity={0.22} />
          <stop offset="100%" stopColor={color} stopOpacity={0} />
        </linearGradient>
      </defs>
      <path d={area} fill={`url(#${gradId})`} />
      <path d={path} fill="none" stroke={color} strokeWidth={1.6} />
    </svg>
  )
}
