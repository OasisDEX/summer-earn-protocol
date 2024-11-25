import dotenv from 'dotenv'
import { AbiEvent, createPublicClient, http } from 'viem'
import { arbitrum } from 'viem/chains'

dotenv.config()

const lzEndpointAbi = [
  // LzReceiveAlert event
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'address',
        name: 'receiver',
        type: 'address',
      },
      {
        indexed: true,
        internalType: 'address',
        name: 'executor',
        type: 'address',
      },
      {
        components: [
          { internalType: 'uint32', name: 'srcEid', type: 'uint32' },
          { internalType: 'bytes32', name: 'sender', type: 'bytes32' },
          { internalType: 'uint64', name: 'nonce', type: 'uint64' },
        ],
        indexed: false,
        internalType: 'struct Origin',
        name: 'origin',
        type: 'tuple',
      },
      // ... other fields ...
    ],
    name: 'LzReceiveAlert',
    type: 'event',
  },
  // PacketDelivered event
  {
    anonymous: false,
    inputs: [
      {
        components: [
          { internalType: 'uint32', name: 'srcEid', type: 'uint32' },
          { internalType: 'bytes32', name: 'sender', type: 'bytes32' },
          { internalType: 'uint64', name: 'nonce', type: 'uint64' },
        ],
        indexed: false,
        internalType: 'struct Origin',
        name: 'origin',
        type: 'tuple',
      },
      {
        indexed: false,
        internalType: 'address',
        name: 'receiver',
        type: 'address',
      },
    ],
    name: 'PacketDelivered',
    type: 'event',
  },
]

async function main() {
  const arbClient = createPublicClient({
    chain: arbitrum,
    transport: http(process.env.ARBITRUM_RPC_URL),
  })

  // Get current block
  const currentBlock = await arbClient.getBlockNumber()

  // Look back approximately 3 days worth of blocks
  // Arbitrum produces roughly 1 block every 0.25 seconds
  // So 3 days = 72 hours * 3600 seconds/hour * 4 blocks/second = ~1,036,800 blocks
  const fromBlock = currentBlock - 1036800n

  console.log('\nSearching from block', fromBlock.toString(), 'to', currentBlock.toString())

  // Search for both types of events
  for (const eventName of ['LzReceiveAlert', 'PacketDelivered']) {
    console.log(`\nSearching for ${eventName} events...`)

    const events = await arbClient.getLogs({
      address: process.env.ARB_ENDPOINT_ADDRESS! as `0x${string}`,
      event:
        eventName === 'LzReceiveAlert'
          ? (lzEndpointAbi[0] as AbiEvent)
          : (lzEndpointAbi[1] as AbiEvent),
      fromBlock,
      toBlock: currentBlock,
      args: {
        // Only filter by receiver for PacketDelivered as it's not indexed in LzReceiveAlert
        receiver: process.env.ARB_ENDPOINT_ADDRESS! as `0x${string}`,
      },
    })

    console.log(`\nFound ${events.length} ${eventName} events:`)
    console.log(events)
  }
}

main()
