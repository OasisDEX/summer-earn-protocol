export const summerVestingWalletFactoryV2Abi = [
  {
    type: 'function',
    name: 'token',
    inputs: [],
    outputs: [{ type: 'address', name: '' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'vestingWallets',
    inputs: [{ type: 'address', name: 'beneficiary' }],
    outputs: [{ type: 'address', name: 'vestingWallet' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'vestingWalletOwners',
    inputs: [{ type: 'address', name: 'vestingWallet' }],
    outputs: [{ type: 'address', name: 'beneficiary' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'createVestingWallet',
    inputs: [
      { type: 'address', name: 'beneficiary' },
      {
        type: 'tuple',
        components: [
          { type: 'uint64', name: 'cliffEndTimestamp' },
          { type: 'uint256', name: 'cliffAmount' },
          { type: 'uint256', name: 'totalVestingAmount' },
          { type: 'uint256', name: 'vestingPeriods' },
        ],
        name: 'vestingParams',
      },
      {
        type: 'tuple[]',
        components: [
          { type: 'uint256', name: 'amount' },
          { type: 'string', name: 'description' },
          { type: 'bool', name: 'reached' },
        ],
        name: 'performanceGoals',
      },
    ],
    outputs: [{ type: 'address', name: 'newVestingWallet' }],
    stateMutability: 'nonpayable',
  },
] as const
