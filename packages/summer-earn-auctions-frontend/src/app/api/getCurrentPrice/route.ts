import { CHAIN_CONFIGS } from '@/lib/config'
import { createPublicClient, http } from 'viem'

export async function POST(request: Request) {
  const { chainId, arkAddress, rewardAddress } = await request.json()

  const config = CHAIN_CONFIGS[chainId]
  if (!config) {
    return Response.json({ error: 'Invalid chain ID' }, { status: 400 })
  }

  const publicClient = createPublicClient({
    chain: config.chain,
    transport: http(config.rpcUrl),
  })

  try {
    const currentPrice = await publicClient.readContract({
      address: config.raftAddress as `0x${string}`,
      abi: [
        {
          inputs: [
            { type: 'address', name: 'arkAddress' },
            { type: 'address', name: 'rewardAddress' },
          ],
          name: 'getCurrentPrice',
          outputs: [{ type: 'uint256', name: '' }],
          stateMutability: 'view',
          type: 'function',
        },
      ],
      functionName: 'getCurrentPrice',
      args: [arkAddress as `0x${string}`, rewardAddress as `0x${string}`],
    })
    return Response.json({ currentPrice: currentPrice.toString() })
  } catch (error) {
    return Response.json({ error: 'Failed to fetch price' }, { status: 500 })
  }
}
