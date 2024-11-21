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
])

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

  // Prepare proposal parameters
  const srcTargets = [HUB_SUMMER_GOVERNOR_ADDRESS]
  const srcValues = [0n]
  const dstDescription = 'Enable transfers on Arbitrum SummerToken'
  const srcDescription = `Cross-chain proposal: ${dstDescription}`

  // Prepare the cross-chain message parameters
  const srcCalldatas = [
    encodeFunctionData({
      abi: parseAbi([
        'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
      ]),
      args: [
        Number(ARB_ENDPOINT_ID),
        [ARB_SUMMER_TOKEN_ADDRESS],
        [0n],
        [
          encodeFunctionData({
            abi: parseAbi(['function enableTransfers()']),
            args: [],
          }),
        ],
        keccak256(toBytes(dstDescription)),
        '0x', // Default options
      ],
    }),
  ]

  // Basic executor options with 200k gas for destination execution
  const options = '0x0003010011010000000000000000000000000000030d40' // 200,000 gas in hex

  try {
    console.log('Executing proposal...')
    console.log('Source targets:', srcTargets)
    console.log('Source values:', srcValues)
    console.log('Source calldatas:', srcCalldatas)
    console.log('Source description hash:', keccak256(toBytes(srcDescription)))

    // Execute with a hardcoded value for LayerZero fees (0.1 ETH should be more than enough for testnet)
    const hash = await walletClient.writeContract({
      address: HUB_SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'execute',
      args: [srcTargets, srcValues, srcCalldatas, keccak256(toBytes(srcDescription)), options],
      value: 50000000000000000n, // 0.05 ETH
      gas: 1000000n,
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
