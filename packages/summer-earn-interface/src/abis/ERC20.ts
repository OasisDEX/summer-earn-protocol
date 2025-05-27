export const erc20Abi = [
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
    inputs: [{ type: 'address', name: '_owner' }],
    outputs: [{ type: 'uint256', name: 'balance' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'allowance',
    inputs: [
      { type: 'address', name: '_owner' },
      { type: 'address', name: '_spender' }
    ],
    outputs: [{ type: 'uint256', name: 'remaining' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'approve',
    inputs: [
      { type: 'address', name: '_spender' },
      { type: 'uint256', name: '_value' }
    ],
    outputs: [{ type: 'bool', name: 'success' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'transfer',
    inputs: [
      { type: 'address', name: '_to' },
      { type: 'uint256', name: '_value' }
    ],
    outputs: [{ type: 'bool', name: 'success' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'transferFrom',
    inputs: [
      { type: 'address', name: '_from' },
      { type: 'address', name: '_to' },
      { type: 'uint256', name: '_value' }
    ],
    outputs: [{ type: 'bool', name: 'success' }],
    stateMutability: 'nonpayable'
  }
] as const; 