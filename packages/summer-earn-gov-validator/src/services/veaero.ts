import { getAddress } from 'viem'

import { SupportedChainId } from '@/config/constants'
import { getPublicClient } from '@/config/rpc'

/**
 * Values veAERO (vote-escrowed AERO) locks held by an owner.
 *
 * veAERO is Aerodrome's `VotingEscrow` ERC721: locking AERO mints a veNFT whose
 * `locked(tokenId)` records the underlying AERO `amount`. For treasury accounting
 * we value the lock at its underlying AERO (priced at AERO spot), not its decaying
 * voting power. We enumerate the owner's veNFTs and sum their locked amounts.
 *
 * Never throws — on any read error it logs and returns 0n so the treasury page
 * still renders (mirrors services/slipstream.ts).
 */

// Aerodrome VotingEscrow on Base. veAERO has 18 decimals (same as AERO).
export const VE_AERO_ESCROW: Record<number, string> = {
  8453: '0xeBf418Fe2512e7E6bd9b87a8F0f294aCDC67e6B4',
}

const VOTING_ESCROW_ABI = [
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'owner', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'ownerToNFTokenIdList',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'index', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'locked',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [
      { name: 'amount', type: 'int128' },
      { name: 'end', type: 'uint256' },
      { name: 'isPermanent', type: 'bool' },
    ],
  },
] as const

// Returns the total underlying AERO (18 decimals) locked across all veAERO NFTs the
// owner holds on the given chain. Returns 0n when the owner holds none or on error.
export async function getVeAeroLockedAmount(
  chainId: SupportedChainId,
  owner: string,
): Promise<bigint> {
  const escrowAddress = VE_AERO_ESCROW[chainId]
  if (!escrowAddress) return 0n

  try {
    const client = getPublicClient(chainId)
    const escrow = getAddress(escrowAddress)
    const ownerAddress = getAddress(owner)

    const nftCount = (await client.readContract({
      address: escrow,
      abi: VOTING_ESCROW_ABI,
      functionName: 'balanceOf',
      args: [ownerAddress],
    })) as bigint
    if (nftCount === 0n) return 0n

    // Enumerate the owner's veNFT token ids.
    const tokenIds = await Promise.all(
      Array.from({ length: Number(nftCount) }, (_, i) =>
        client
          .readContract({
            address: escrow,
            abi: VOTING_ESCROW_ABI,
            functionName: 'ownerToNFTokenIdList',
            args: [ownerAddress, BigInt(i)],
          })
          .catch(() => null),
      ),
    )

    const lockedAmounts = await Promise.all(
      tokenIds
        .filter((id): id is bigint => id !== null && (id as bigint) > 0n)
        .map((id) =>
          client
            .readContract({
              address: escrow,
              abi: VOTING_ESCROW_ABI,
              functionName: 'locked',
              args: [id],
            })
            .then((res) => (res as readonly [bigint, bigint, boolean])[0])
            .catch(() => 0n),
        ),
    )

    // `amount` is int128; locks are non-negative in practice but clamp defensively.
    return lockedAmounts.reduce((sum, amount) => sum + (amount > 0n ? amount : 0n), 0n)
  } catch (error) {
    console.error(`Error valuing veAERO locks for ${owner} on chain ${chainId}:`, error)
    return 0n
  }
}
