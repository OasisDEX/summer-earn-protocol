'use client'

import { useState } from 'react'
import { createAppKit } from '@reown/appkit/react'
import {
  mainnet as appkitMainnet,
  base as appkitBase,
  arbitrum as appkitArbitrum,
} from '@reown/appkit/networks'
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { WagmiProvider } from 'wagmi'
import { Toaster } from 'sonner'

const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_ID || 'b56e18d47c72ab683b10814fe9495694' // Fallback demo ID

const networks = [appkitMainnet, appkitBase, appkitArbitrum]

export const wagmiAdapter = new WagmiAdapter({
  projectId,
  networks,
})

createAppKit({
  adapters: [wagmiAdapter],
  networks,
  projectId,
  metadata: {
    name: 'Summer Earn Oracle Dashboard',
    description: 'RWA Oracle Monitoring',
    url: 'https://summer.fi',
    icons: ['https://assets.reown.com/reown-profile-pic.png'],
  },
})

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient())

  return (
    <WagmiProvider config={wagmiAdapter.wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        {children}
        <Toaster richColors position="top-right" />
      </QueryClientProvider>
    </WagmiProvider>
  )
}
