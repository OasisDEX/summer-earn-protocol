// Trimmed Permit2 surface: IAllowanceTransfer's allowance/approve/permit only.
// (Source: packages/core-contracts/src/interfaces/permit2/IPermit2.sol)
//
// The DCAStrategyManager pulls funds via PERMIT2.transferFrom(owner, manager, amount, sourceVault).
// That requires the on-chain Permit2 allowance ledger to be populated by either:
//  - the user calling Permit2.approve(token, spender, amount, expiration), or
//  - submitting Permit2.permit(owner, permitSingle, signature) with an EIP-712 sig.

export const permit2Abi = [
  {
    type: 'function',
    name: 'allowance',
    stateMutability: 'view',
    inputs: [
      { name: 'user', type: 'address' },
      { name: 'token', type: 'address' },
      { name: 'spender', type: 'address' },
    ],
    outputs: [
      { name: 'amount', type: 'uint160' },
      { name: 'expiration', type: 'uint48' },
      { name: 'nonce', type: 'uint48' },
    ],
  },
  {
    type: 'function',
    name: 'approve',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'token', type: 'address' },
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint160' },
      { name: 'expiration', type: 'uint48' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'permit',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'owner', type: 'address' },
      {
        name: 'permitSingle',
        type: 'tuple',
        components: [
          {
            name: 'details',
            type: 'tuple',
            components: [
              { name: 'token', type: 'address' },
              { name: 'amount', type: 'uint160' },
              { name: 'expiration', type: 'uint48' },
              { name: 'nonce', type: 'uint48' },
            ],
          },
          { name: 'spender', type: 'address' },
          { name: 'sigDeadline', type: 'uint256' },
        ],
      },
      { name: 'signature', type: 'bytes' },
    ],
    outputs: [],
  },
  {
    type: 'event',
    name: 'Approval',
    anonymous: false,
    inputs: [
      { name: 'owner', type: 'address', indexed: true },
      { name: 'token', type: 'address', indexed: true },
      { name: 'spender', type: 'address', indexed: true },
      { name: 'amount', type: 'uint160', indexed: false },
      { name: 'expiration', type: 'uint48', indexed: false },
    ],
  },
  {
    type: 'event',
    name: 'Permit',
    anonymous: false,
    inputs: [
      { name: 'owner', type: 'address', indexed: true },
      { name: 'token', type: 'address', indexed: true },
      { name: 'spender', type: 'address', indexed: true },
      { name: 'amount', type: 'uint160', indexed: false },
      { name: 'expiration', type: 'uint48', indexed: false },
      { name: 'nonce', type: 'uint48', indexed: false },
    ],
  },
] as const
