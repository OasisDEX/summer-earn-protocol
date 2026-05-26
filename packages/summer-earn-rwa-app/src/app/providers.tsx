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
import { Toaster } from 'sonner'
import { WagmiProvider } from 'wagmi'
import { arbitrum, base, hyperliquid, mainnet, sonic } from 'wagmi/chains'

import { CHAIN_RPC_URLS, createRpcTransport } from '@/config/chains'
import { getWalletConnectProjectId } from '@/config/env'

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 30_000,
            refetchOnWindowFocus: false,
          },
        },
      }),
  )

  const projectId = getWalletConnectProjectId()

  // AppKit Hyperliquid mainnet isn't exported in older bundles; pass the four
  // canonical networks for the WalletConnect modal — wagmi still understands
  // the full chain list.
  const appkitNetworks = useMemo(
    () => [appkitBase, appkitMainnet, appkitArbitrum, appkitSonic],
    [],
  ) as Parameters<typeof createAppKit>[0]['networks']

  const wagmiAdapter = useMemo(() => {
    return new WagmiAdapter({
      projectId,
      ssr: true,
      networks: appkitNetworks,
      chains: [base, mainnet, arbitrum, sonic, hyperliquid],
      transports: {
        [base.id]: createRpcTransport(CHAIN_RPC_URLS[base.id]),
        [mainnet.id]: createRpcTransport(CHAIN_RPC_URLS[mainnet.id]),
        [arbitrum.id]: createRpcTransport(CHAIN_RPC_URLS[arbitrum.id]),
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
        name: 'Summer Earn RWA',
        description:
          'Institutional deposits, settlement, and admin for Summer.fi rounds-vault wrapped fleets',
        url: typeof window !== 'undefined' ? window.location.origin : 'https://example.org',
        icons: [],
      },
    })
    ;(window as WindowWithAppKit).appKit = appKit
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
