'use client'

import { useAccount, useDisconnect } from 'wagmi'

import { useMounted } from '@/hooks/useMounted'
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
  // wagmi reads the cached connection from localStorage on the client,
  // so SSR renders "Connect wallet" while a returning user's first client
  // render would render their address. Match the server output until the
  // post-mount commit, then let wagmi state drive the real branch.
  const mounted = useMounted()

  if (!mounted || !isConnected || !address) {
    return <Button onClick={() => window.appKit?.open()}>Connect wallet</Button>
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
