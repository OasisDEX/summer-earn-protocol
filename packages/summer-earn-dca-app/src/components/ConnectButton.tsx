'use client'

import { useAccount, useDisconnect } from 'wagmi'

import { shortAddress } from '@/lib/format'

import { Button } from './ui/Button'

declare global {
  interface Window {
    appKit?: { open: () => void }
  }
}

export function ConnectButton() {
  const { address, isConnected } = useAccount()
  const { disconnect } = useDisconnect()

  if (!isConnected || !address) {
    return (
      <Button onClick={() => window.appKit?.open()}>Connect wallet</Button>
    )
  }

  return (
    <div className="flex items-center gap-2">
      <Button variant="secondary" onClick={() => window.appKit?.open()}>
        {shortAddress(address)}
      </Button>
      <Button variant="ghost" onClick={() => disconnect()}>
        Disconnect
      </Button>
    </div>
  )
}
