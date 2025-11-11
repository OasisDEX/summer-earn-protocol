import { createPublicClient, http } from 'viem'

import { CHAIN_CONFIGS } from '@/lib/config'

export async function POST(request: Request) {
  try {
    const { chainId, arkAddress, rewardAddress, raftAddress } = await request.json()

    if (!chainId || !arkAddress || !rewardAddress || !raftAddress) {
      return Response.json(
        { error: 'Missing required parameters: chainId, arkAddress, rewardAddress, raftAddress' },
        { status: 400 },
      )
    }

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
        address: raftAddress as `0x${string}`,
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
      console.error('Error fetching price:', error)
      return Response.json({ error: 'Failed to fetch price' }, { status: 500 })
    }
  } catch (error) {
    console.error('Error parsing request:', error)
    return Response.json({ error: 'Invalid request format' }, { status: 400 })
  }
}
