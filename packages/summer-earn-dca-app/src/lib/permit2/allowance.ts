import type { Address, PublicClient } from 'viem'

import { erc20Abi } from '@/abis/ERC20'
import { permit2Abi } from '@/abis/Permit2'
import { PERMIT2_ADDRESS } from '@/config/addresses'

export interface Permit2AllowanceResult {
  amount: bigint
  expiration: number
  nonce: number
}

// Standard ERC20 allowance held by Permit2 on behalf of the owner.
// Reading the source-vault ERC20 (FleetCommander share token), not the underlying asset.
export async function readErc20AllowanceToPermit2(
  client: PublicClient,
  token: Address,
  owner: Address,
): Promise<bigint> {
  return client.readContract({
    address: token,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [owner, PERMIT2_ADDRESS],
  })
}

// Permit2's per-(owner,token,spender) allowance ledger entry.
// `expiration` is a uint48 unix timestamp; 0 means uninitialised.
export async function readPermit2Allowance(
  client: PublicClient,
  owner: Address,
  token: Address,
  spender: Address,
): Promise<Permit2AllowanceResult> {
  const result = await client.readContract({
    address: PERMIT2_ADDRESS,
    abi: permit2Abi,
    functionName: 'allowance',
    args: [owner, token, spender],
  })
  return {
    amount: result[0],
    expiration: result[1],
    nonce: result[2],
  }
}

// True when the on-chain Permit2 allowance is sufficient to cover `required`
// shares and is not expired. Either condition forces a fresh approve/permit.
export function isPermit2AllowanceSufficient(
  allowance: Permit2AllowanceResult,
  required: bigint,
  nowSeconds = Math.floor(Date.now() / 1000),
): boolean {
  if (allowance.amount < required) return false
  if (allowance.expiration === 0) return false
  if (allowance.expiration <= nowSeconds) return false
  return true
}
