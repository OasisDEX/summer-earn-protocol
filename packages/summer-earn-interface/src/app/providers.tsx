'use client'

import { useEffect, useMemo, useState } from 'react'
import { createAppKit } from '@reown/appkit'
import {
  arbitrum as appkitArbitrum,
  base as appkitBase,
  mainnet as appkitMainnet,
} from '@reown/appkit/networks'
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Toaster } from 'sonner'
import { http,WagmiProvider } from 'wagmi'
import { arbitrum, base, mainnet, sonic } from 'wagmi/chains'

import { CHAIN_RPC_URLS } from '@/config/chains'

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient())

  const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_ID || 'demo'

  const appkitNetworks = useMemo(() => [appkitMainnet, appkitArbitrum, appkitBase] as const, [])

  const wagmiAdapter = useMemo(() => {
    return new WagmiAdapter({
      projectId,
      ssr: true,
      networks: appkitNetworks as any,
      chains: [mainnet, arbitrum, base, sonic],
      transports: {
        [mainnet.id]: http(CHAIN_RPC_URLS[mainnet.id]),
        [arbitrum.id]: http(CHAIN_RPC_URLS[arbitrum.id]),
        [base.id]: http(CHAIN_RPC_URLS[base.id]),
        [sonic.id]: http(CHAIN_RPC_URLS[sonic.id]),
      },
    })
  }, [projectId, appkitNetworks])

  useEffect(() => {
    const appKit = createAppKit({
      adapters: [wagmiAdapter],
      networks: appkitNetworks as any,
      projectId,
      metadata: {
        name: 'Summer Earn Protocol Interface',
        description: 'A simple interface for Summer Earn Protocol',
        url: typeof window !== 'undefined' ? window.location.origin : 'https://example.org',
        icons: [],
      },
    })
    ;(window as any).appKit = appKit
  }, [projectId, wagmiAdapter, appkitNetworks])

  return (
    <WagmiProvider config={wagmiAdapter.wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        {children}
        <Toaster richColors position="top-right" />
      </QueryClientProvider>
    </WagmiProvider>
  )
}
