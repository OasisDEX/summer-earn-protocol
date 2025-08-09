'use client'

import { CHAIN_RPC_URLS } from '@/config/chains'
import { getDefaultConfig, RainbowKitProvider } from '@rainbow-me/rainbowkit'
import '@rainbow-me/rainbowkit/styles.css'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'
import { http, WagmiProvider } from 'wagmi'
import { arbitrum, base, mainnet, sonic } from 'wagmi/chains'
import { Toaster } from 'sonner'

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient())

  const config = getDefaultConfig({
    appName: 'Summer Earn Protocol Interface',
    projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_ID || 'demo',
    chains: [mainnet, arbitrum, base, sonic],
    transports: {
      [mainnet.id]: http(CHAIN_RPC_URLS[mainnet.id]),
      [arbitrum.id]: http(CHAIN_RPC_URLS[arbitrum.id]),
      [base.id]: http(CHAIN_RPC_URLS[base.id]),
      [sonic.id]: http(CHAIN_RPC_URLS[sonic.id]),
    },
    ssr: true,
  })

  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          {children}
          <Toaster richColors position="top-right" />
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  )
}
