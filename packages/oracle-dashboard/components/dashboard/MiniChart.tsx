'use client'

import React from 'react'

interface MiniChartProps {
  data: { price: number; timestamp: number }[]
  color?: string
}

export function MiniChart({ data, color = '#3b82f6' }: MiniChartProps) {
  if (!data || data.length < 2) {
    return (
      <div className="h-full w-full flex items-center justify-center text-[10px] text-slate-400 italic">
        No history
      </div>
    )
  }

  const values = data.map((d) => d.price)
  const min = Math.min(...values)
  const max = Math.max(...values)
  const range = max - min || 1

  const width = 100
  const height = 40
  const padding = 4

  const points = data
    .map((d, i) => {
      const x = (i / (data.length - 1)) * width
      const y = height - padding - ((d.price - min) / range) * (height - 2 * padding)
      return `${x},${y}`
    })
    .join(' ')

  return (
    <div className="w-full h-full min-h-[40px]">
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className="w-full h-full overflow-visible"
        preserveAspectRatio="none"
      >
        <polyline
          fill="none"
          stroke={color}
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          points={points}
          className="drop-shadow-sm"
        />
        {/* Subtle area fill */}
        <polygon
          points={`0,${height} ${points} ${width},${height}`}
          fill={color}
          fillOpacity="0.05"
        />
      </svg>
    </div>
  )
}
