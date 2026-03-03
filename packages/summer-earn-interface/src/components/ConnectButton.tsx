'use client'

import { useCallback } from 'react'
import { useAccount, useDisconnect } from 'wagmi'

type WindowWithAppKit = typeof window & {
  appKit?: {
    open?: () => void
  }
}

export function ConnectButton() {
  const { address, isConnected } = useAccount()
  const { disconnectAsync } = useDisconnect()

  const onOpen = useCallback(() => {
    ;(window as WindowWithAppKit).appKit?.open?.()
  }, [])

  const onDisconnect = useCallback(async () => {
    try {
      await disconnectAsync()
    } catch (error) {
      console.error('Failed to disconnect wallet', error)
    }
  }, [disconnectAsync])

  if (!isConnected) {
    return (
      <button
        onClick={onOpen}
        className="bg-primary hover:bg-primary/90 text-white px-4 py-2 rounded-lg text-sm font-semibold transition-all shadow-lg shadow-primary/20"
      >
        Connect
      </button>
    )
  }

  const short = `${address?.slice(0, 6)}…${address?.slice(-4)}`

  return (
    <div className="flex items-center gap-2">
      <button
        onClick={onOpen}
        className="flex items-center space-x-3 bg-primary/10 hover:bg-primary/20 border border-primary/30 px-4 py-2 rounded-lg transition-all group"
        title={address || ''}
      >
        <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
        <span className="text-sm font-medium text-white">{short}</span>
        <span className="text-sm text-primary group-hover:translate-x-0.5 transition-transform">
          ▼
        </span>
      </button>
      <button
        onClick={onDisconnect}
        className="px-2 py-1.5 rounded-lg bg-red-500/20 text-red-400 hover:bg-red-500/30 text-xs font-medium transition-colors"
        aria-label="Disconnect"
      >
        Disconnect
      </button>
    </div>
  )
}
