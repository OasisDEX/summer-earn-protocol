import dotenv from 'dotenv'
import {
  Address,
  createPublicClient,
  createWalletClient,
  encodeFunctionData,
  Hex,
  http,
  parseAbi,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { base } from 'viem/chains'

dotenv.config()

// Contract addresses
const TIMELOCK_ADDRESS = process.env.TIMELOCK_ADDRESS as Address
const SUMMER_GOVERNOR_ADDRESS = process.env.SUMMER_GOVERNOR_ADDRESS as Address

// SummerGovernor ABI (only the propose function)
const governorAbi = parseAbi([
  'function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) public returns (uint256)',
])

async function main() {
  // Setup public client
  const publicClient = createPublicClient({
    chain: base,
    transport: http(process.env.RPC_URL),
  })

  // Setup wallet client
  const account = privateKeyToAccount(`0x${process.env.PRIVATE_KEY as Hex}`)
  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http(process.env.RPC_URL),
  })

  // Prepare the proposal data
  const newMinDelay = 3600n // 1 hour in seconds
  const calldatas = [
    encodeFunctionData({
      abi: parseAbi(['function updateDelay(uint256 newDelay)']),
      args: [newMinDelay],
    }),
  ]

  const targets = [TIMELOCK_ADDRESS]
  const values = [0n]
  const description = `Update TimelockController minimum delay to ${newMinDelay} seconds (1 hour)`

  try {
    console.log('Preparing to submit proposal...')
    console.log('Target:', targets[0])
    console.log('Value:', values[0])
    console.log('Calldata:', calldatas[0])
    console.log('Description:', description)

    const hash = await walletClient.writeContract({
      address: SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'propose',
      args: [targets, values, calldatas, description],
    })

    console.log('Proposal submitted. Transaction hash:', hash)

    // Wait for the transaction to be mined
    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    console.log('Transaction mined. Block number:', receipt.blockNumber)
  } catch (error: any) {
    console.error('Error submitting proposal:', error)
    if (error.cause) {
      console.error('Error cause:', error.cause)
    }
  }
}

main().catch(console.error)
