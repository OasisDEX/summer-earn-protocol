'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'

import { revalidateVestingData } from '@/app/actions'

export function RefreshButton({ lastUpdated }: { lastUpdated: number }) {
  const [disabled, setDisabled] = useState(true)
  const [timeLeft, setTimeLeft] = useState('')
  const router = useRouter()
  const COOLDOWN_MS = 5 * 60 * 1000 // 5 Minutes

  useEffect(() => {
    const checkTime = () => {
      const now = Date.now()
      const diff = now - lastUpdated

      if (diff < COOLDOWN_MS) {
        setDisabled(true)
        const remaining = Math.ceil((COOLDOWN_MS - diff) / 1000)
        const mins = Math.floor(remaining / 60)
        const secs = remaining % 60
        setTimeLeft(`${mins}:${secs.toString().padStart(2, '0')}`)
      } else {
        setDisabled(false)
        setTimeLeft('')
      }
    }

    // Check immediately and every second
    checkTime()
    const interval = setInterval(checkTime, 1000)
    return () => clearInterval(interval)
  }, [lastUpdated])

  const handleRefresh = async () => {
    if (disabled) return
    setDisabled(true) // Optimistic disable
    await revalidateVestingData()
    router.refresh() // Refresh Server Components
  }

  return (
    <div className="relative group inline-block">
      <button
        onClick={handleRefresh}
        disabled={disabled}
        className={`px-4 py-2 rounded font-mono text-xs font-bold transition-all ${
          disabled
            ? 'bg-white/5 text-on-surface-variant/60 cursor-not-allowed'
            : 'bg-primary text-on-primary hover:bg-primary-dim shadow-lg hover:shadow-primary/20'
        }`}
      >
        {disabled ? `COOLING DOWN (${timeLeft})` : 'INVALIDATE CACHE'}
      </button>

      {disabled && (
        <div className="absolute bottom-full mb-2 left-1/2 -translate-x-1/2 w-48 p-2 bg-surface-container-lowest border border-white/10 rounded text-[11px] text-center text-on-surface-variant opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">
          Updates limited to once every 5 minutes.
        </div>
      )}
    </div>
  )
}
