import dotenv from 'dotenv'
import { createPublicClient, decodeFunctionData, http } from 'viem'
import { base } from 'viem/chains'

dotenv.config()

// Simplified ABI for the relevant functions
const governorAbi = [
  {
    inputs: [
      { internalType: 'address[]', name: 'targets', type: 'address[]' },
      { internalType: 'uint256[]', name: 'values', type: 'uint256[]' },
      { internalType: 'bytes[]', name: 'calldatas', type: 'bytes[]' },
      { internalType: 'bytes32', name: 'descriptionHash', type: 'bytes32' },
    ],
    name: 'execute',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'payable',
    type: 'function',
  },
] as const

async function main() {
  const baseClient = createPublicClient({
    chain: base,
    transport: http(process.env.BASE_RPC_URL),
  })

  const txHash = '0x0bc0740a64946bd6b3045a9779ce1befb776fccbc403439f1a17264f548c7ef5' // Add the full hash here

  // Get the transaction
  const tx = await baseClient.getTransaction({ hash: txHash as `0x${string}` })
  console.log('\nTransaction Details:')
  console.log('From:', tx.from)
  console.log('To:', tx.to)
  console.log('Value:', tx.value)

  // Decode the input data
  try {
    const decodedData = decodeFunctionData({
      abi: governorAbi,
      data: tx.input,
    })

    if (decodedData.args) {
      const [targets, values, calldatas, descriptionHash] = decodedData.args

      console.log('\nDecoded Governor Execute Call:')
      console.log('Function:', decodedData.functionName)
      console.log('Targets:', targets)
      console.log('Values:', values)
      console.log('Calldatas:', calldatas)
      console.log('Description Hash:', descriptionHash)

      // Try to decode each calldata if possible
      console.log('\nDecoded Calldatas:')
      calldatas.forEach((calldata, i) => {
        console.log(`\nCalldata ${i + 1}:`)
        console.log('Raw:', calldata)
        if (typeof calldata === 'string') {
          console.log('Function Selector:', calldata.slice(0, 10))
        }
      })
    }
  } catch (error) {
    console.error('Error decoding input:', error)
  }

  // Get the transaction receipt for logs
  const receipt = await baseClient.getTransactionReceipt({ hash: txHash as `0x${string}` })

  // Find and decode the LayerZero message event
  const messageSentEvent = receipt.logs.find(
    (log) => log.topics[0] === '0x97c3d2068ce177bc33d84acecc45eededc36656d0684ad3cd29b9be5da5628a0', // PacketSent event
  )

  if (messageSentEvent) {
    console.log('\nLayerZero Message Details:')
    console.log('Raw Event Data:', messageSentEvent.data)
  }
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
