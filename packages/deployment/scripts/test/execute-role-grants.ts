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
const TIMELOCK_ADDRESS = process.env.TIMELOCK_ADDRESS as Address
const SUMMER_GOVERNOR_ADDRESS = process.env.SUMMER_GOVERNOR_ADDRESS as Address

// Role identifiers
const PROPOSER_ROLE = keccak256(toBytes('PROPOSER_ROLE'))
const CANCELLER_ROLE = keccak256(toBytes('CANCELLER_ROLE'))
const EXECUTOR_ROLE = keccak256(toBytes('EXECUTOR_ROLE'))

// TimelockController ABI (only the execute function)
const timelockAbi = parseAbi([
  'function execute(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt) public payable',
])

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

  // Prepare the execution data
  const calldatas = [
    encodeFunctionData({
      abi: parseAbi(['function grantRole(bytes32 role, address account)']),
      args: [PROPOSER_ROLE, SUMMER_GOVERNOR_ADDRESS],
    }),
    encodeFunctionData({
      abi: parseAbi(['function grantRole(bytes32 role, address account)']),
      args: [CANCELLER_ROLE, SUMMER_GOVERNOR_ADDRESS],
    }),
    encodeFunctionData({
      abi: parseAbi(['function grantRole(bytes32 role, address account)']),
      args: [EXECUTOR_ROLE, SUMMER_GOVERNOR_ADDRESS],
    }),
  ]

  const targets = [TIMELOCK_ADDRESS, TIMELOCK_ADDRESS, TIMELOCK_ADDRESS]
  const values = [0n, 0n, 0n]
  const predecessor = '0x0000000000000000000000000000000000000000000000000000000000000000'
  const salt = keccak256(toBytes('Grant roles to SummerGovernor'))

  try {
    console.log('Preparing to execute proposals on TimelockController...')

    for (let i = 0; i < targets.length; i++) {
      console.log(`Executing proposal ${i + 1}...`)
      console.log('Target:', targets[i])
      console.log('Value:', values[i])
      console.log('Calldata:', calldatas[i])

      const hash = await walletClient.writeContract({
        address: TIMELOCK_ADDRESS,
        abi: timelockAbi,
        functionName: 'execute',
        args: [targets[i], values[i], calldatas[i], predecessor, salt],
      })

      console.log(`Proposal ${i + 1} executed. Transaction hash:`, hash)

      // Wait for the transaction to be mined
      const receipt = await publicClient.waitForTransactionReceipt({ hash })
      console.log(`Proposal ${i + 1} transaction mined. Block number:`, receipt.blockNumber)
    }
  } catch (error: any) {
    console.error('Error executing proposal:', error)
    if (error.cause) {
      console.error('Error cause:', error.cause)
    }
  }
}

main().catch(console.error)
