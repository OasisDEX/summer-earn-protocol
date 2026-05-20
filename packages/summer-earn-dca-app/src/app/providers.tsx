'use client'

import { useEffect, useMemo, useState } from 'react'
import { createAppKit } from '@reown/appkit'
import { base as appkitBase } from '@reown/appkit/networks'
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Toaster } from 'sonner'
import { WagmiProvider } from 'wagmi'
import { base } from 'wagmi/chains'

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

  const appkitNetworks = useMemo(
    () => [appkitBase],
    [],
  ) as Parameters<typeof createAppKit>[0]['networks']

  const wagmiAdapter = useMemo(() => {
    return new WagmiAdapter({
      projectId,
      ssr: true,
      networks: appkitNetworks,
      chains: [base],
      transports: {
        [base.id]: createRpcTransport(CHAIN_RPC_URLS[base.id]),
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
        name: 'Summer Earn DCA',
        description: 'Dollar-cost-averaging strategies on Summer.fi vaults',
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
