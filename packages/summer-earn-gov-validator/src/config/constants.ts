export const ERC20_ABI = [
  {
    constant: true,
    inputs: [{ name: '_owner', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: 'balance', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    constant: true,
    inputs: [],
    name: 'decimals',
    outputs: [{ name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    constant: true,
    inputs: [],
    name: 'symbol',
    outputs: [{ name: '', type: 'string' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    constant: true,
    inputs: [],
    name: 'name',
    outputs: [{ name: '', type: 'string' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

export interface TokenInfo {
  address: string
  name: string
  symbol: string
  decimals: number
  logoURI?: string
  chainId: number
}

export const CHAIN_CONFIG = {
  1: {
    name: 'Mainnet',
    timelock: '0x447BF9d1485ABDc4C1778025DfdfbE8b894C3796',
    summerToken: '0x194f360D130F2393a5E9F3117A6a1B78aBEa1624',
  },
  8453: {
    name: 'Base',
    timelock: '0x447BF9d1485ABDc4C1778025DfdfbE8b894C3796',
    summerToken: '0x194f360D130F2393a5E9F3117A6a1B78aBEa1624',
  },
  42161: {
    name: 'Arbitrum',
    timelock: '0x447BF9d1485ABDc4C1778025DfdfbE8b894C3796',
    summerToken: '0x194f360D130F2393a5E9F3117A6a1B78aBEa1624',
  },
  146: {
    name: 'Sonic',
    timelock: '0x4c32A28AD95deaBc06bF7C83AdEbCF6fe6721ED9',
    summerToken: '0x4e0037f487bBb588bf1B7a83BDe6c34FeD6099e3',
  },
  999: {
    name: 'HyperEVM',
    timelock: '0x244c6EFC140b9cC4D69d3bf4d9137Dc4195Be86c',
    summerToken: '0x72c527d3efDe2169AA950EFc9573C838cf125D21',
  },
} as const

export type SupportedChainId = keyof typeof CHAIN_CONFIG
