import { createPublicClient, http } from 'viem'
import { arbitrum, base, mainnet } from 'viem/chains'

// Create public clients for each chain
export const publicClients = {
  [mainnet.id]: createPublicClient({
    chain: mainnet,
    transport: http('https://mainnet.infura.io/v3/ffa4874465f948b6befcfd3f2f792f87'),
  }),
  [base.id]: createPublicClient({
    chain: base,
    transport: http('https://base-mainnet.infura.io/v3/ffa4874465f948b6befcfd3f2f792f87'),
  }),
  [arbitrum.id]: createPublicClient({
    chain: arbitrum,
    transport: http('https://arbitrum-mainnet.infura.io/v3/ffa4874465f948b6befcfd3f2f792f87'),
  }),
}

// ABI fragment for getCurrentPrice
export const auctionAbi = [
  {
    inputs: [
      { internalType: 'address', name: 'ark', type: 'address' },
      { internalType: 'address', name: 'rewardToken', type: 'address' },
    ],
    name: 'getCurrentPrice',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const
