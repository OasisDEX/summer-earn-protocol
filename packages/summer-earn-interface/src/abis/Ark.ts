export const arkAbi = [
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
    name: 'name',
    inputs: [],
    outputs: [{ type: 'string', name: '' }],
  }
] as const; 