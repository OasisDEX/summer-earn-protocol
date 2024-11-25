import dotenv from 'dotenv'
import { createPublicClient, http } from 'viem'
import { arbitrum } from 'viem/chains'

dotenv.config()

const lzEndpointAbi = [
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
      {
        indexed: false,
        internalType: 'bytes32',
        name: 'guid',
        type: 'bytes32',
      },
      {
        indexed: false,
        internalType: 'uint256',
        name: 'gas',
        type: 'uint256',
      },
      {
        indexed: false,
        internalType: 'uint256',
        name: 'value',
        type: 'uint256',
      },
      {
        indexed: false,
        internalType: 'bytes',
        name: 'message',
        type: 'bytes',
      },
      {
        indexed: false,
        internalType: 'bytes',
        name: 'extraData',
        type: 'bytes',
      },
      {
        indexed: false,
        internalType: 'bytes',
        name: 'reason',
        type: 'bytes',
      },
    ],
    name: 'LzReceiveAlert',
    type: 'event',
  },
]

async function findLzReceiveTransaction(
  dstClient: any,
  dstEndpoint: string,
  dstOApp: string,
  srcEid: number,
  messageNonce: number,
  fromBlock: bigint,
  toBlock: bigint,
) {
  console.log('\n=== Searching for LzReceiveAlert events ===')
  console.log('Destination OApp:', dstOApp)
  console.log('Source EID:', srcEid)
  console.log('Message Nonce:', messageNonce)
  console.log('Block range:', fromBlock, 'to', toBlock)

  const events = await dstClient.getLogs({
    address: dstEndpoint as `0x${string}`,
    event: lzEndpointAbi[0],
    args: {
      receiver: dstOApp as `0x${string}`,
    },
    fromBlock,
    toBlock,
  })

  console.log('\nFound', events.length, 'LzReceiveAlert events')

  for (const event of events) {
    const origin = event.args.origin
    if (origin.srcEid === srcEid && origin.nonce === BigInt(messageNonce)) {
      console.log('\n=== Found Matching Event ===')
      console.log('Transaction Hash:', event.transactionHash)
      console.log('Block Number:', event.blockNumber)
      console.log('GUID:', event.args.guid)
      console.log('Gas Used:', event.args.gas)
      console.log(
        'Error Reason:',
        event.args.reason ? Buffer.from(event.args.reason.slice(2), 'hex').toString() : 'No error',
      )
      return event
    }
  }

  console.log('\n❌ No matching event found')
  return null
}

async function main() {
  const arbClient = createPublicClient({
    chain: arbitrum,
    transport: http(process.env.ARBITRUM_RPC_URL),
  })

  // Get the current block
  const currentBlock = await arbClient.getBlockNumber()

  // Search last 1000 blocks - adjust this range as needed
  const fromBlock = currentBlock - 1000n

  await findLzReceiveTransaction(
    arbClient,
    process.env.ARB_ENDPOINT_ADDRESS!,
    process.env.ARB_SUMMER_GOVERNOR_ADDRESS!,
    30184, // Base EID
    2, // Message nonce
    fromBlock,
    currentBlock,
  )
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
