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

// SummerGovernor ABI (only the propose function)
const governorAbi = parseAbi([
  'function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) public returns (uint256)',
])

// TimelockController ABI (only the schedule function)
const timelockAbi = parseAbi([
  'function schedule(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt, uint256 delay) public',
])

async function clearPendingTransactions(
  walletClient: any,
  publicClient: any,
  account: { address: Address },
) {
  const latestNonce = await publicClient.getTransactionCount({ address: account.address })
  const pendingNonce = await publicClient.getTransactionCount({
    address: account.address,
    blockTag: 'pending',
  })

  if (pendingNonce > latestNonce) {
    console.log(`Clearing ${pendingNonce - latestNonce} pending transactions...`)
    for (let nonce = latestNonce; nonce < pendingNonce; nonce++) {
      const gasPrice = await publicClient.getGasPrice()
      const increasedGasPrice = BigInt(Math.floor(Number(gasPrice) * 2)) // Double the gas price

      try {
        const hash = await walletClient.sendTransaction({
          to: account.address,
          value: 0n,
          nonce: BigInt(nonce),
          gasPrice: increasedGasPrice,
        })

        console.log(`Sent clearing transaction for nonce ${nonce}. Hash: ${hash}`)
        await publicClient.waitForTransactionReceipt({ hash })
      } catch (error) {
        console.error(`Failed to clear transaction with nonce ${nonce}:`, error)
      }
    }
    console.log('All pending transactions cleared.')
  } else {
    console.log('No pending transactions found.')
  }
}

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

  // Clear pending transactions
  await clearPendingTransactions(walletClient, publicClient, account)

  // Prepare the proposal data
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
  const delay = 172800n // 2 days in seconds, adjust as needed

  // Get the current nonce
  const nonce = await publicClient.getTransactionCount({ address: account.address })

  // Get the current gas price and increase it significantly
  const currentGasPrice = await publicClient.getGasPrice()
  const increasedGasPrice = (currentGasPrice * 200n) / 100n // Double the gas price

  console.log(`Using nonce: ${nonce}`)
  console.log(`Current gas price: ${currentGasPrice}`)
  console.log(`Increased gas price: ${increasedGasPrice}`)

  try {
    console.log('Preparing to submit proposals to TimelockController...')

    for (let i = 0; i < targets.length; i++) {
      console.log(`Scheduling proposal ${i + 1}...`)
      console.log('Target:', targets[i])
      console.log('Value:', values[i])
      console.log('Calldata:', calldatas[i])

      const hash = await walletClient.writeContract({
        address: TIMELOCK_ADDRESS,
        abi: timelockAbi,
        functionName: 'schedule',
        args: [targets[i], values[i], calldatas[i], predecessor, salt, delay],
        // nonce: nonce + BigInt(i), // Uncomment if you want to use nonce
        // gasPrice: increasedGasPrice,
      })

      console.log(`Proposal ${i + 1} scheduled. Transaction hash:`, hash)

      // Wait for the transaction to be mined
      const receipt = await publicClient.waitForTransactionReceipt({ hash })
      console.log(`Proposal ${i + 1} transaction mined. Block number:`, receipt.blockNumber)
    }
  } catch (error: any) {
    console.error('Error submitting proposal:', error)
    if (error.cause) {
      console.error('Error cause:', error.cause)
    }
  }
}

main().catch(console.error)
