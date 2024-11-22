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

const HUB_SUMMER_GOVERNOR_ADDRESS = process.env.BASE_SUMMER_GOVERNOR_ADDRESS as Address
const ARB_SUMMER_TOKEN_ADDRESS = process.env.ARB_SUMMER_TOKEN_ADDRESS as Address
const ARB_ENDPOINT_ID = process.env.ARB_ENDPOINT_ID as string

const governorAbi = parseAbi([
  'function execute(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) public payable returns (uint256)',
  'function state(uint256 proposalId) public view returns (uint8)',
  'function hashProposal(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) public pure returns (uint256)',
  'error GovernorNonexistentProposal(uint256)',
])

// Add helper function to match the test file's approach
function hashDescription(description: string): Hex {
  return keccak256(toBytes(description))
}

// Add gas estimation for better cross-chain handling
const GAS_FOR_RELAY = 200000n // 200k gas units
const NATIVE_FEE = 50000000000000000n // 0.05 ETH

async function verifyOAppConfiguration(publicClient: PublicClient) {
  // Add verification for OApp configuration
  console.log('Verifying OApp configuration...')

  // Add your verification logic here
  // This could include checking the endpoint configuration
  // and OApp registration on both chains

  // Example:
  const endpointConfig = await publicClient.readContract({
    address: HUB_SUMMER_GOVERNOR_ADDRESS,
    abi: parseAbi(['function endpoint() view returns (address)']),
    functionName: 'endpoint',
  })

  console.log('Endpoint configuration:', endpointConfig)
}

async function main() {
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

  // Update parameters to exactly match the proposal that was created
  const dstTargets = [ARB_SUMMER_TOKEN_ADDRESS] // '0xA62aF16aD97B01aC7AB10122B453C0630a37e48c'
  const dstValues = [0n]
  const dstCalldatas = [
    encodeFunctionData({
      abi: parseAbi(['function enableTransfers()']),
      args: [],
    }) as Hex, // This should result in '0xaf35c6c7'
  ]
  const dstDescription = 'Enable transfers on Arbitrum SummerToken (v3)'

  // Prepare the Base-side parameters (source) - exact match to proposal
  const srcTargets = [HUB_SUMMER_GOVERNOR_ADDRESS] // '0x82e3992f7C78c40DC540723b2c2e9c84877a87eC'
  const srcValues = [0n]
  const srcDescription = `Cross-chain proposal: ${dstDescription}`

  // Update LzOptions to match the exact format used in proposal
  const lzOptions = '0x00030100110100000000000000000000000000030d4001000104' as Hex

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

  try {
    // Verify the parameters match before execution
    console.log('Verifying proposal parameters match...')
    console.log('Source description hash (should match):', hashDescription(srcDescription))
    // Expected: 0x16232692e144d47687beb22ed03b007d5b6e76a01c61564f78e5c71cda2c4624

    const proposalId = await publicClient.readContract({
      address: HUB_SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'hashProposal',
      args: [srcTargets, srcValues, srcCalldatas, hashDescription(srcDescription)],
    })

    console.log('Calculated proposal ID:', proposalId)

    // Check the proposal state
    const state = await publicClient.readContract({
      address: HUB_SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'state',
      args: [proposalId],
    })

    console.log('Proposal ID:', proposalId)
    console.log('Proposal State:', state) // 0=Pending, 1=Active, 2=Canceled, 3=Defeated, 4=Succeeded, 5=Queued, 6=Expired, 7=Executed

    if (state !== 5) {
      // 5 = Queued
      throw new Error(`Proposal is not in queued state. Current state: ${state}`)
    }

    // Get current gas price for better estimation
    const gasPrice = await publicClient.getGasPrice()

    console.log('Current gas price:', gasPrice)

    // Call this before executing
    await verifyOAppConfiguration(publicClient)

    console.log('Executing proposal...')
    const hash = await walletClient.writeContract({
      address: HUB_SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'execute',
      args: [srcTargets, srcValues, srcCalldatas, hashDescription(srcDescription)],
      value: 0n, // As should be paid by Governor
      gas: GAS_FOR_RELAY,
      maxFeePerGas: gasPrice + (gasPrice * 20n) / 100n, // Add 20% buffer
    })

    console.log('Execution submitted. Transaction hash:', hash)
    console.log('Waiting for transaction receipt...')

    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    console.log('Execution transaction mined. Block number:', receipt.blockNumber)

    // Add verification steps
    console.log('Verifying transaction status...')
    console.log('Transaction receipt:', receipt)

    if (receipt.status === 'success') {
      console.log(
        'Transaction succeeded! Please check LayerZero scan for cross-chain delivery status',
      )
      console.log(`LayerZero scan URL: https://layerzeroscan.com/tx/${hash}`)
    } else {
      throw new Error('Transaction failed!')
    }
  } catch (error: any) {
    console.error('Error executing proposal:', error)
    if (error.cause) {
      console.error('Error cause:', error.cause)
    }
    throw error
  }
}

main().catch(console.error)
