export const wisdomTreeArkAbi = [
  {
    type: 'function',
    name: 'pendingDepositAssets',
    inputs: [],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'sharesToAssets',
    inputs: [{ type: 'uint256', name: 'shares' }],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'clearPendingDeposit',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
] as const
