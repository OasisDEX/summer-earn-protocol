import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { arbitrum, base, mainnet } from 'wagmi/chains'

// Custom chain for Sonic
const sonic = {
  id: 146,
  name: 'Sonic',
  nativeCurrency: {
    decimals: 18,
    name: 'Sonic',
    symbol: 'S',
  },
  rpcUrls: {
    default: {
      http: ['https://rpc.soniclabs.com'],
    },
  },
  blockExplorers: {
    default: { name: 'Sonic Explorer', url: 'https://explorer.soniclabs.com' },
  },
} as const

export const config = getDefaultConfig({
  appName: 'Summer Earn Governance Validator',
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'YOUR_PROJECT_ID', // Get this from WalletConnect Cloud
  chains: [mainnet, base, arbitrum, sonic],
  ssr: true, // If your dApp uses server side rendering (SSR)
})
