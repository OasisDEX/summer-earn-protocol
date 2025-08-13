export const summerVestingWalletFactoryAbi = [
  {
    type: 'function',
    name: 'vestingWallets',
    inputs: [{ type: 'address', name: 'beneficiary' }],
    outputs: [{ type: 'address', name: 'vestingWallet' }],
    stateMutability: 'view',
  },
] as const


