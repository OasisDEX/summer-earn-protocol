export const summerVestingWalletAbi = [
  {
    type: 'function',
    name: 'owner',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
  {
    type: 'function',
    name: 'transferOwnership',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'newOwner', type: 'address' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'token',
    inputs: [],
    outputs: [{ type: 'address', name: '' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getVestingType',
    inputs: [],
    outputs: [{ type: 'uint8', name: '' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'timeBasedVestingAmount',
    inputs: [],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'goalAmounts',
    inputs: [{ type: 'uint256', name: '' }],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'goalsReached',
    inputs: [{ type: 'uint256', name: '' }],
    outputs: [{ type: 'bool', name: '' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'releasable',
    inputs: [{ type: 'address', name: 'token' }],
    outputs: [{ type: 'uint256', name: 'amount' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'released',
    inputs: [{ type: 'address', name: 'token' }],
    outputs: [{ type: 'uint256', name: 'amount' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'vestedAmount',
    inputs: [
      { type: 'address', name: 'token' },
      { type: 'uint64', name: 'timestamp' },
    ],
    outputs: [{ type: 'uint256', name: 'amount' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'release',
    inputs: [{ type: 'address', name: 'token' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
] as const


