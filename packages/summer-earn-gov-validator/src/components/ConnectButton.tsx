'use client'

import { useCallback } from 'react'
import { useAccount, useDisconnect } from 'wagmi'

type WindowWithAppKit = typeof window & {
  appKit?: {
    open?: () => void
  }
}

export function ConnectButton() {
  const { address, isConnected, chain } = useAccount()
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
        className="px-3 py-1.5 rounded-md bg-primary-600 text-white hover:bg-primary-500 transition"
      >
        Connect Wallet
      </button>
    )
  }

  const short = `${address?.slice(0, 6)}…${address?.slice(-4)}`

  return (
    <div className="flex items-center gap-2">
      <button
        onClick={onOpen}
        className="px-3 py-1.5 rounded-md bg-gray-700 text-white border border-white/10 hover:bg-gray-600 transition"
        title={address || ''}
      >
        {short}
        {chain ? ` · ${chain.name}` : ''}
      </button>
      <button
        onClick={onDisconnect}
        className="px-2 py-1 rounded-md bg-red-600/80 text-white hover:bg-red-500 transition"
        aria-label="Disconnect"
      >
        Disconnect
      </button>
    </div>
  )
}
