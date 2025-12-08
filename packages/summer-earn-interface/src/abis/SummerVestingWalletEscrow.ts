export const summerVestingWalletEscrowAbi = [
    {
      type: 'function',
      name: 'vestingFactories',
      stateMutability: 'view',
      inputs: [],
      outputs: [{ name: 'factories', type: 'address[]' }],
    },
    {
      type: 'function',
      name: 'userStakedVestingFactories',
      stateMutability: 'view',
      inputs: [{ name: 'user', type: 'address' }],
      outputs: [{ name: 'factories', type: 'address[]' }],
    },
    {
      type: 'function',
      name: 'stakeVesting',
      stateMutability: 'nonpayable',
      inputs: [{ name: 'factories', type: 'address[]' }],
      outputs: [],
    },
    {
      type: 'function',
      name: 'unstakeVesting',
      stateMutability: 'nonpayable',
      inputs: [{ name: 'factories', type: 'address[]' }],
      outputs: [],
    },
  ] as const