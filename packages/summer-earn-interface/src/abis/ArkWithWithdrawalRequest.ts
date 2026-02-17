/**
 * Minimal ABI for IArkWithWithdrawalRequest interface.
 * Use with allowFailure for arks that may not implement this interface.
 */
export const arkWithWithdrawalRequestAbi = [
  {
    type: 'function',
    name: 'withdrawalRequestId',
    inputs: [],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'assetsInWithdrawalQueue',
    inputs: [],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'isWithdrawalClaimRequired',
    inputs: [],
    outputs: [{ type: 'bool', name: '' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'requestWithdrawal',
    inputs: [{ type: 'uint256', name: 'amount' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'claimWithdrawal',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'sweep',
    inputs: [],
    outputs: [
      { type: 'address[]', name: 'sweptTokens' },
      { type: 'uint256[]', name: 'sweptAmounts' },
    ],
    stateMutability: 'nonpayable',
  },
] as const
