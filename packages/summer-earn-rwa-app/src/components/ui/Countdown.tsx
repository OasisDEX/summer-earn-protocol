'use client'

import { useEffect, useState } from 'react'

interface CountdownProps {
  targetSec?: bigint | number
  className?: string
}

function format(diffMs: number): string {
  if (diffMs <= 0) return 'now'
  const totalSec = Math.floor(diffMs / 1000)
  const d = Math.floor(totalSec / 86_400)
  const h = Math.floor((totalSec % 86_400) / 3600)
  const m = Math.floor((totalSec % 3600) / 60)
  if (d > 0) return `${d}d ${h}h ${m.toString().padStart(2, '0')}m`
  if (h > 0) return `${h}h ${m.toString().padStart(2, '0')}m`
  return `${m}m`
}

export function Countdown({ targetSec, className = '' }: CountdownProps) {
  const targetMs = Number(targetSec ?? 0) * 1000
  const [now, setNow] = useState<number>(() => Date.now())

  useEffect(() => {
    if (!targetMs) return
    const id = setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(id)
  }, [targetMs])

  if (!targetMs) return <span className={['font-mono', className].join(' ')}>—</span>
  return (
    <span className={['font-mono tabular-nums', className].join(' ')}>
      {format(targetMs - now)}
    </span>
  )
}
