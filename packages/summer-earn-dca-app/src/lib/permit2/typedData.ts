import type { Address } from 'viem'

import { PERMIT2_ADDRESS } from '@/config/addresses'

// EIP-712 typed-data shape for Permit2's AllowanceTransfer.permit(...).
// Matches the canonical Uniswap Permit2 PermitSingle struct:
//   struct PermitDetails { address token; uint160 amount; uint48 expiration; uint48 nonce; }
//   struct PermitSingle  { PermitDetails details; address spender; uint256 sigDeadline; }

export const PERMIT2_DOMAIN_NAME = 'Permit2'

export interface PermitDetails {
  token: Address
  amount: bigint
  expiration: number
  nonce: number
}

export interface PermitSingle {
  details: PermitDetails
  spender: Address
  sigDeadline: bigint
}

export function buildPermitSingleTypedData(opts: {
  chainId: number
  permitSingle: PermitSingle
}) {
  return {
    domain: {
      name: PERMIT2_DOMAIN_NAME,
      chainId: opts.chainId,
      verifyingContract: PERMIT2_ADDRESS,
    },
    types: {
      PermitDetails: [
        { name: 'token', type: 'address' },
        { name: 'amount', type: 'uint160' },
        { name: 'expiration', type: 'uint48' },
        { name: 'nonce', type: 'uint48' },
      ],
      PermitSingle: [
        { name: 'details', type: 'PermitDetails' },
        { name: 'spender', type: 'address' },
        { name: 'sigDeadline', type: 'uint256' },
      ],
    },
    primaryType: 'PermitSingle',
    message: opts.permitSingle,
  } as const
}
