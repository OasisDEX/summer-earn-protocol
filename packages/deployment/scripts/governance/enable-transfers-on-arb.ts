import { Options } from '@layerzerolabs/lz-v2-utilities'
import dotenv from 'dotenv'
import {
  Address,
  createPublicClient,
  createWalletClient,
  encodeFunctionData,
  Hex,
  http,
  keccak256,
  parseAbi,
  toBytes,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { base } from 'viem/chains'

dotenv.config()

// Contract addresses
const HUB_SUMMER_GOVERNOR_ADDRESS = process.env.BASE_SUMMER_GOVERNOR_ADDRESS as Address
const ARB_SUMMER_TOKEN_ADDRESS = process.env.ARB_SUMMER_TOKEN_ADDRESS as Address
const ARB_ENDPOINT_ID = process.env.ARB_ENDPOINT_ID as string // LayerZero chain ID for Arbitrum

// Governor ABI (only the needed functions)
const governorAbi = parseAbi([
  'function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) public returns (uint256)',
  'function hashProposal(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) public pure returns (uint256)',
])

// Add a helper function to match the test file's approach
function hashDescription(description: string): Hex {
  return keccak256(toBytes(description))
}

// Helper function to construct LayerZero options
function constructLzOptions(gasLimit: bigint = 200000n): Hex {
  // Create new options instance and add required execution options
  const options = Options.newOptions()
    // Add gas for lzReceive execution on destination
    .addExecutorLzReceiveOption(Number(gasLimit), 0) // (gas limit, msg.value)
    // Add ordered execution option to ensure proper message ordering
    .addExecutorOrderedExecutionOption()

  return options.toHex() as Hex
}

async function main() {
  // Setup clients
  const publicClient = createPublicClient({
    chain: base,
    transport: http(process.env.RPC_URL),
  })

  const account = privateKeyToAccount(`0x${process.env.PRIVATE_KEY as Hex}`)
  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http(process.env.RPC_URL),
  })

  // Prepare the Arbitrum-side proposal parameters (target proposal)
  const dstTargets = [ARB_SUMMER_TOKEN_ADDRESS]
  const dstValues = [0n]
  const dstCalldatas = [
    encodeFunctionData({
      abi: parseAbi(['function enableTransfers()']),
      args: [],
    }) as Hex,
  ]
  const dstDescription = 'Enable transfers on Arbitrum SummerToken (v2)'

  console.log('Destination description:', dstDescription)
  console.log('Hashed destination description:', hashDescription(dstDescription))
  console.log('LayerZero options:', constructLzOptions(200000n))
  console.log('Destination targets:', dstTargets)
  console.log('Destination values:', dstValues)
  console.log('Destination calldatas:', dstCalldatas)

  // Prepare the Base-side proposal parameters (source proposal)
  const srcTargets = [HUB_SUMMER_GOVERNOR_ADDRESS]
  const srcValues = [0n]

  // Construct proper LayerZero options
  const lzOptions = constructLzOptions(200000n) // 200k gas for destination execution

  // Encode the cross-chain message parameters
  const srcCalldatas = [
    encodeFunctionData({
      abi: parseAbi([
        'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
      ]),
      args: [
        Number(ARB_ENDPOINT_ID),
        dstTargets,
        dstValues,
        dstCalldatas,
        hashDescription(dstDescription),
        lzOptions,
      ],
    }) as Hex,
  ]

  const srcDescription = `Cross-chain proposal: ${dstDescription}`

  try {
    console.log('Preparing to submit cross-chain proposal...')
    console.log('Source targets:', srcTargets)
    console.log('Source values:', srcValues)
    console.log('Source calldatas:', srcCalldatas)
    console.log('Source description:', srcDescription)
    console.log('Hashed description:', hashDescription(srcDescription))

    // throw new Error('Not implemented')
    console.log('Simulation successful, proceeding with transaction...')

    // Submit the proposal with explicit gas parameters
    const hash = await walletClient.writeContract({
      address: HUB_SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'propose',
      args: [srcTargets, srcValues, srcCalldatas, srcDescription],
      gas: 500000n, // Set a reasonable gas limit
      maxFeePerGas: await publicClient.getGasPrice(), // Use current gas price
    })

    console.log('Proposal submitted. Transaction hash:', hash)

    // Wait for the transaction to be mined
    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    console.log('Proposal transaction mined. Block number:', receipt.blockNumber)

    // Get the proposal ID
    const proposalId = await publicClient.readContract({
      address: HUB_SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'hashProposal',
      args: [srcTargets, srcValues, srcCalldatas, hashDescription(srcDescription)],
    })

    console.log('Proposal ID:', proposalId)
  } catch (error: any) {
    console.error('Error submitting proposal:', error)
    if (error.cause) {
      console.error('Error cause:', error.cause)
      // Add more detailed error information
      if (error.cause.data) {
        console.error('Error data:', error.cause.data)
      }
    }
  }
}

main().catch(console.error)
