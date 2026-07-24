import { getAddress } from 'viem'

import { SupportedChainId } from '@/config/constants'
import { getPublicClient } from '@/config/rpc'

/**
 * Values Aerodrome Slipstream (concentrated-liquidity) positions that an owner
 * holds via a "Wrapped Staked Slipstream Positions" wrapper.
 *
 * Flow (verified on Base for the Arcadia PoL account): the owner holds a wrapped
 * position NFT minted by `wrapper`; the underlying NFPM position (same token id)
 * is staked in the pool's CL gauge by the wrapper. So we enumerate the gauge's
 * staked token ids for the wrapper, keep the ones the owner currently owns on the
 * wrapper, then read each position and compute its underlying token amounts.
 */

const POOL_ABI = [
  {
    name: 'slot0',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [
      { name: 'sqrtPriceX96', type: 'uint160' },
      { name: 'tick', type: 'int24' },
      { name: 'observationIndex', type: 'uint16' },
      { name: 'observationCardinality', type: 'uint16' },
      { name: 'observationCardinalityNext', type: 'uint16' },
      { name: 'unlocked', type: 'bool' },
    ],
  },
  {
    name: 'gauge',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
] as const

const GAUGE_ABI = [
  {
    name: 'nft',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
  {
    name: 'stakedValues',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'depositor', type: 'address' }],
    outputs: [{ name: '', type: 'uint256[]' }],
  },
] as const

const WRAPPER_ABI = [
  {
    name: 'ownerOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ name: '', type: 'address' }],
  },
] as const

const NFPM_ABI = [
  {
    name: 'positions',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [
      { name: 'nonce', type: 'uint96' },
      { name: 'operator', type: 'address' },
      { name: 'token0', type: 'address' },
      { name: 'token1', type: 'address' },
      { name: 'tickSpacing', type: 'int24' },
      { name: 'tickLower', type: 'int24' },
      { name: 'tickUpper', type: 'int24' },
      { name: 'liquidity', type: 'uint128' },
      { name: 'feeGrowthInside0LastX128', type: 'uint256' },
      { name: 'feeGrowthInside1LastX128', type: 'uint256' },
      { name: 'tokensOwed0', type: 'uint128' },
      { name: 'tokensOwed1', type: 'uint128' },
    ],
  },
] as const

const Q96 = 1n << 96n
const UINT256_MAX = (1n << 256n) - 1n

// Uniswap V3 TickMath.getSqrtRatioAtTick — exact integer implementation.
function getSqrtRatioAtTick(tick: number): bigint {
  const absTick = BigInt(tick < 0 ? -tick : tick)
  let ratio =
    (absTick & 0x1n) !== 0n
      ? 0xfffcb933bd6fad37aa2d162d1a594001n
      : 0x100000000000000000000000000000000n
  const m = (c: bigint) => {
    ratio = (ratio * c) >> 128n
  }
  if (absTick & 0x2n) m(0xfff97272373d413259a46990580e213an)
  if (absTick & 0x4n) m(0xfff2e50f5f656932ef12357cf3c7fdccn)
  if (absTick & 0x8n) m(0xffe5caca7e10e4e61c3624eaa0941cd0n)
  if (absTick & 0x10n) m(0xffcb9843d60f6159c9db58835c926644n)
  if (absTick & 0x20n) m(0xff973b41fa98c081472e6896dfb254c0n)
  if (absTick & 0x40n) m(0xff2ea16466c96a3843ec78b326b52861n)
  if (absTick & 0x80n) m(0xfe5dee046a99a2a811c461f1969c3053n)
  if (absTick & 0x100n) m(0xfcbe86c7900a88aedcffc83b479aa3a4n)
  if (absTick & 0x200n) m(0xf987a7253ac413176f2b074cf7815e54n)
  if (absTick & 0x400n) m(0xf3392b0822b70005940c7a398e4b70f3n)
  if (absTick & 0x800n) m(0xe7159475a2c29b7443b29c7fa6e889d9n)
  if (absTick & 0x1000n) m(0xd097f3bdfd2022b8845ad8f792aa5825n)
  if (absTick & 0x2000n) m(0xa9f746462d870fdf8a65dc1f90e061e5n)
  if (absTick & 0x4000n) m(0x70d869a156d2a1b890bb3df62baf32f7n)
  if (absTick & 0x8000n) m(0x31be135f97d08fd981231505542fcfa6n)
  if (absTick & 0x10000n) m(0x9aa508b5b7a84e1c677de54f3e99bc9n)
  if (absTick & 0x20000n) m(0x5d6af8dedb81196699c329225ee604n)
  if (absTick & 0x40000n) m(0x2216e584f5fa1ea926041bedfe98n)
  if (absTick & 0x80000n) m(0x48a170391f7dc42444e8fa2n)

  if (tick > 0) ratio = UINT256_MAX / ratio

  // Round up to Q96 (matches Solidity's shift-and-round).
  return (ratio >> 32n) + (ratio % (1n << 32n) === 0n ? 0n : 1n)
}

function amount0(sqrtA: bigint, sqrtB: bigint, liquidity: bigint): bigint {
  if (sqrtA > sqrtB) [sqrtA, sqrtB] = [sqrtB, sqrtA]
  return ((liquidity << 96n) * (sqrtB - sqrtA)) / sqrtB / sqrtA
}

function amount1(sqrtA: bigint, sqrtB: bigint, liquidity: bigint): bigint {
  if (sqrtA > sqrtB) [sqrtA, sqrtB] = [sqrtB, sqrtA]
  return (liquidity * (sqrtB - sqrtA)) / Q96
}

// Uniswap V3 LiquidityAmounts.getAmountsForLiquidity.
function getAmountsForLiquidity(
  sqrtP: bigint,
  sqrtA: bigint,
  sqrtB: bigint,
  liquidity: bigint,
): { amount0: bigint; amount1: bigint } {
  if (sqrtA > sqrtB) [sqrtA, sqrtB] = [sqrtB, sqrtA]
  if (sqrtP <= sqrtA) return { amount0: amount0(sqrtA, sqrtB, liquidity), amount1: 0n }
  if (sqrtP < sqrtB)
    return { amount0: amount0(sqrtP, sqrtB, liquidity), amount1: amount1(sqrtA, sqrtP, liquidity) }
  return { amount0: 0n, amount1: amount1(sqrtA, sqrtB, liquidity) }
}

export interface SlipstreamTokenAmount {
  tokenAddress: string
  amount: bigint
}

export interface SlipstreamPositionConfig {
  pool: string
  wrapper: string
}

// Returns the total underlying token amounts (by token address) across all of the
// owner's wrapped staked positions in the given pool. Never throws — on any read
// error it logs and returns an empty list so the treasury page still renders.
export async function getWrappedSlipstreamTokenAmounts(
  chainId: SupportedChainId,
  owner: string,
  config: SlipstreamPositionConfig,
): Promise<SlipstreamTokenAmount[]> {
  try {
    const client = getPublicClient(chainId)
    const pool = getAddress(config.pool)
    const wrapper = getAddress(config.wrapper)
    const ownerAddress = getAddress(owner)

    const [slot0, gauge] = await Promise.all([
      client.readContract({ address: pool, abi: POOL_ABI, functionName: 'slot0' }),
      client.readContract({ address: pool, abi: POOL_ABI, functionName: 'gauge' }),
    ])
    const sqrtPriceX96 = slot0[0] as bigint
    const gaugeAddress = getAddress(gauge as string)

    const [nfpm, stakedIds] = await Promise.all([
      client.readContract({ address: gaugeAddress, abi: GAUGE_ABI, functionName: 'nft' }),
      client.readContract({
        address: gaugeAddress,
        abi: GAUGE_ABI,
        functionName: 'stakedValues',
        args: [wrapper],
      }),
    ])
    const nfpmAddress = getAddress(nfpm as string)
    const ids = stakedIds as readonly bigint[]
    if (ids.length === 0) return []

    // Fetch every staked id's wrapper owner and NFPM position in one concurrent
    // burst (the client's multicall batching folds these into a single request),
    // then keep only the positions currently owned by `owner`. Positions for ids
    // we end up discarding cost nothing extra — they ride in the same multicall.
    const [owners, positions] = await Promise.all([
      Promise.all(
        ids.map((id) =>
          client
            .readContract({
              address: wrapper,
              abi: WRAPPER_ABI,
              functionName: 'ownerOf',
              args: [id],
            })
            .catch(() => null),
        ),
      ),
      Promise.all(
        ids.map((id) =>
          client
            .readContract({
              address: nfpmAddress,
              abi: NFPM_ABI,
              functionName: 'positions',
              args: [id],
            })
            .catch(() => null),
        ),
      ),
    ])

    const totals = new Map<string, bigint>()
    ids.forEach((_, i) => {
      const posOwner = owners[i]
      const p = positions[i] as readonly unknown[] | null
      if (!p || !posOwner || (posOwner as string).toLowerCase() !== ownerAddress.toLowerCase()) {
        return
      }
      const token0 = getAddress(p[2] as string)
      const token1 = getAddress(p[3] as string)
      const tickLower = Number(p[5] as bigint | number)
      const tickUpper = Number(p[6] as bigint | number)
      const liquidity = p[7] as bigint
      if (liquidity === 0n) return

      const { amount0: a0, amount1: a1 } = getAmountsForLiquidity(
        sqrtPriceX96,
        getSqrtRatioAtTick(tickLower),
        getSqrtRatioAtTick(tickUpper),
        liquidity,
      )
      totals.set(token0, (totals.get(token0) ?? 0n) + a0)
      totals.set(token1, (totals.get(token1) ?? 0n) + a1)
    })

    return Array.from(totals.entries())
      .filter(([, amount]) => amount > 0n)
      .map(([tokenAddress, amount]) => ({ tokenAddress, amount }))
  } catch (error) {
    console.error(`Error valuing Slipstream positions for ${owner} on chain ${chainId}:`, error)
    return []
  }
}
