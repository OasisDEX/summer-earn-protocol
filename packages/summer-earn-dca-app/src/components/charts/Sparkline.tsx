interface SparklineProps {
  points: number[]
  height?: number
  width?: number
  color?: string
  className?: string
}

// Minimal inline SVG line — last N price points. No axes, no markers.
// Used in the KPI tiles row on the Dashboard.
export function Sparkline({
  points,
  height = 32,
  width = 88,
  color = 'var(--pink)',
  className = '',
}: SparklineProps) {
  if (!points || points.length < 2) {
    return (
      <svg width={width} height={height} className={className} aria-hidden>
        <line
          x1={0}
          y1={height / 2}
          x2={width}
          y2={height / 2}
          stroke="var(--border-faint)"
          strokeWidth={1}
        />
      </svg>
    )
  }

  const min = Math.min(...points)
  const max = Math.max(...points)
  const span = max - min || 1
  const stepX = width / (points.length - 1)

  const d = points
    .map((p, i) => {
      const x = i * stepX
      const y = height - ((p - min) / span) * (height - 4) - 2
      return `${i === 0 ? 'M' : 'L'} ${x.toFixed(1)} ${y.toFixed(1)}`
    })
    .join(' ')

  return (
    <svg
      width={width}
      height={height}
      viewBox={`0 0 ${width} ${height}`}
      className={className}
      aria-hidden
    >
      <path d={d} fill="none" stroke={color} strokeWidth={1.4} strokeLinejoin="round" />
    </svg>
  )
}
