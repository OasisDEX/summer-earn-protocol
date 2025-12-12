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
            ? 'bg-gray-700 text-gray-500 cursor-not-allowed'
            : 'bg-blue-600 text-white hover:bg-blue-500 shadow-lg hover:shadow-blue-500/20'
        }`}
      >
        {disabled ? `COOLING DOWN (${timeLeft})` : 'INVALIDATE CACHE'}
      </button>

      {disabled && (
        <div className="absolute bottom-full mb-2 left-1/2 -translate-x-1/2 w-48 p-2 bg-black border border-gray-700 rounded text-[10px] text-center text-gray-300 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">
          Updates limited to once every 5 minutes.
        </div>
      )}
    </div>
  )
}
