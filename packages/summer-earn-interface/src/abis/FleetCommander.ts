export const fleetCommanderAbi = [
  {
    type: 'function',
    name: 'getActiveArks',
    inputs: [],
    outputs: [{ type: 'address[]', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'bufferArk',
    inputs: [],
    outputs: [{ type: 'address', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'totalAssets',
    inputs: [],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'withdrawableTotalAssets',
    inputs: [],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'asset',
    inputs: [],
    outputs: [{ type: 'address', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'name',
    inputs: [],
    outputs: [{ type: 'string', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'symbol',
    inputs: [],
    outputs: [{ type: 'string', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'decimals',
    inputs: [],
    outputs: [{ type: 'uint8', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'balanceOf',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'maxDeposit',
    inputs: [{ type: 'address', name: 'owner' }],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'maxWithdraw',
    inputs: [{ type: 'address', name: 'owner' }],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'deposit',
    inputs: [
      { type: 'uint256', name: 'assets' },
      { type: 'address', name: 'receiver' }
    ],
    outputs: [{ type: 'uint256', name: 'shares' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'withdraw',
    inputs: [
      { type: 'uint256', name: 'assets' },
      { type: 'address', name: 'receiver' },
      { type: 'address', name: 'owner' }
    ],
    outputs: [{ type: 'uint256', name: 'shares' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'rebalance',
    inputs: [
      {
        type: 'tuple[]',
        name: 'rebalanceData',
        components: [
          { type: 'address', name: 'fromArk' },
          { type: 'address', name: 'toArk' },
          { type: 'uint256', name: 'amount' },
          { type: 'bytes', name: 'boardData' },
          { type: 'bytes', name: 'disembarkData' }
        ]
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  }
] as const; 