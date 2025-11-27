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
import { http, WagmiProvider } from 'wagmi'
import { arbitrum, base, mainnet, sonic } from 'wagmi/chains'

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient())

  const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_ID || 'demo'

  const appkitNetworks = useMemo(
    () => [appkitMainnet, appkitArbitrum, appkitBase],
    [],
  ) as Parameters<typeof createAppKit>[0]['networks']

  const wagmiAdapter = useMemo(() => {
    return new WagmiAdapter({
      projectId,
      ssr: true,
      networks: appkitNetworks,
      chains: [mainnet, arbitrum, base, sonic],
      transports: {
        [mainnet.id]: http(mainnet.rpcUrls.default.http[0]),
        [arbitrum.id]: http(arbitrum.rpcUrls.default.http[0]),
        [base.id]: http(base.rpcUrls.default.http[0]),
        [sonic.id]: http(sonic.rpcUrls.default.http[0]),
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
