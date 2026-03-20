'use client'

import { useEffect, useMemo, useState } from 'react'
import { createAppKit } from '@reown/appkit'
import {
  arbitrum as appkitArbitrum,
  base as appkitBase,
  mainnet as appkitMainnet,
  sonic as appkitSonic,
} from '@reown/appkit/networks'
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { WagmiProvider } from 'wagmi'
import { arbitrum, base, hyperliquid, mainnet, sonic } from 'wagmi/chains'

import { CHAIN_RPC_URLS, createRpcTransport } from '@/config/rpc'

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient())

  const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_ID || 'demo'

  const appkitNetworks = useMemo(
    () => [appkitMainnet, appkitArbitrum, appkitBase, appkitSonic, hyperliquid],
    [],
  ) as [any, ...any[]]

  const wagmiAdapter = useMemo(() => {
    return new WagmiAdapter({
      projectId,
      ssr: true,
      networks: appkitNetworks,
      chains: [mainnet, arbitrum, base, sonic, hyperliquid],
      transports: {
        [mainnet.id]: createRpcTransport(CHAIN_RPC_URLS[mainnet.id]),
        [arbitrum.id]: createRpcTransport(CHAIN_RPC_URLS[arbitrum.id]),
        [base.id]: createRpcTransport(CHAIN_RPC_URLS[base.id]),
        [sonic.id]: createRpcTransport(CHAIN_RPC_URLS[sonic.id]),
        [hyperliquid.id]: createRpcTransport(CHAIN_RPC_URLS[hyperliquid.id]),
      },
    })
  }, [projectId, appkitNetworks])

  useEffect(() => {
    type WindowWithAppKit = typeof window & {
      appKit?: ReturnType<typeof createAppKit>
    }

    const appKit = createAppKit({
      adapters: [wagmiAdapter],
      networks: appkitNetworks,
      projectId,
      allowUnsupportedChain: true,
      metadata: {
        name: 'Summer Earn Governance Validator',
        description: 'Validate governance proposals for Summer Earn Protocol',
        url: typeof window !== 'undefined' ? window.location.origin : 'https://example.org',
        icons: [],
      },
    })
    ;(window as WindowWithAppKit).appKit = appKit
  }, [projectId, wagmiAdapter, appkitNetworks])

  return (
    <WagmiProvider config={wagmiAdapter.wagmiConfig}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </WagmiProvider>
  )
}
