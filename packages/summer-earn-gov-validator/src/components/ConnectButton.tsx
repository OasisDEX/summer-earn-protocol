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
  const { disconnect } = useDisconnect()

  const onOpen = useCallback(() => {
    ;(window as WindowWithAppKit).appKit?.open?.()
  }, [])

  const onDisconnect = useCallback(() => {
    disconnect()
  }, [disconnect])

  if (!isConnected) {
    return (
      <button
        onClick={onOpen}
        className="bg-sky-400/10 border border-sky-400/30 text-sky-300 px-5 py-2 rounded-full text-sm font-medium hover:bg-sky-400/20 active:scale-95 duration-200 ease-out transition-all"
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
        className="bg-emerald-400/10 border border-emerald-400/30 text-emerald-400 px-4 py-2 rounded-full text-sm font-medium hover:bg-emerald-400/20 active:scale-95 duration-200 ease-out transition-all flex items-center gap-2"
        title={address || ''}
      >
        <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
        {short}
        {chain ? <span className="text-xs opacity-60">· {chain.name}</span> : ''}
      </button>
      <button
        onClick={onDisconnect}
        className="p-2 rounded-full bg-slate-800 text-slate-400 hover:text-red-400 hover:bg-red-400/10 transition-all active:scale-90"
        aria-label="Disconnect"
      >
        <span className="material-symbols-outlined text-sm">logout</span>
      </button>
    </div>
  )
}
