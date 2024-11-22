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

// Helper function to construct LayerZero options
function constructLzOptions(gasLimit: bigint = 200000n): Hex {
  const optionsType = '0003' // Type 3 options
  const executorFlag = '01' // ExecutorLzReceiveOption
  const optionLength = '0011' // Length of the option
  const version = '01' // Version
  const gasHex = gasLimit.toString(16).padStart(40, '0')

  return `0x${optionsType}${executorFlag}${optionLength}${version}${gasHex}` as Hex
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

  // Prepare the Arbitrum-side parameters (target)
  const dstTargets = [ARB_SUMMER_TOKEN_ADDRESS]
  const dstValues = [0n]
  const dstCalldatas = [
    encodeFunctionData({
      abi: parseAbi(['function enableTransfers()']),
      args: [],
    }),
  ]
  const dstDescription = 'Enable transfers on Arbitrum SummerToken (v2)'

  // Prepare the Base-side parameters (source)
  const srcTargets = [HUB_SUMMER_GOVERNOR_ADDRESS]
  const srcValues = [0n]
  const srcDescription = `Cross-chain proposal: ${dstDescription}`

  // Use proper LayerZero options
  const lzOptions = constructLzOptions(200000n)

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
    }),
  ]

  try {
    // Log all inputs that go into proposal ID calculation
    console.log('Proposal parameters:')
    console.log('Targets:', srcTargets)
    console.log('Values:', srcValues)
    console.log('Calldatas:', srcCalldatas)
    console.log('Description:', srcDescription)
    console.log('Description hash:', hashDescription(srcDescription))

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

    console.log('Executing proposal...')
    const hash = await walletClient.writeContract({
      address: HUB_SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'execute',
      args: [srcTargets, srcValues, srcCalldatas, hashDescription(srcDescription)],
      value: 50000000000000000n, // 0.05 ETH for LayerZero fees
      gas: 1000000n,
      maxFeePerGas: await publicClient.getGasPrice(),
    })

    console.log('Execution submitted. Transaction hash:', hash)
    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    console.log('Execution transaction mined. Block number:', receipt.blockNumber)
  } catch (error: any) {
    console.error('Error executing proposal:', error)
    if (error.cause) {
      console.error('Error cause:', error.cause)
    }
  }
}

main().catch(console.error)
