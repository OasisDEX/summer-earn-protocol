import dotenv from 'dotenv'
import {
  Address,
  createPublicClient,
  createWalletClient,
  encodeFunctionData,
  Hex,
  http,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { arbitrum } from 'viem/chains'

dotenv.config()

// Contract addresses
const TIMELOCK_ADDRESS = process.env.ARB_TIMELOCK_ADDRESS as Address
const PROTOCOL_ACCESS_MANAGER = process.env.ARB_PROTOCOL_ACCESS_MANAGER as Address
const SUMMER_GOVERNOR = process.env.ARB_SUMMER_GOVERNOR_ADDRESS as Address
const RPC_URL = process.env.ARBITRUM_RPC_URL as string
const CHAIN = arbitrum

// Verify addresses are not empty
if (!TIMELOCK_ADDRESS) {
  throw new Error('TIMELOCK_ADDRESS is not set')
}

if (!PROTOCOL_ACCESS_MANAGER) {
  throw new Error('PROTOCOL_ACCESS_MANAGER is not set')
}

if (!SUMMER_GOVERNOR) {
  throw new Error('SUMMER_GOVERNOR is not set')
}

if (!RPC_URL) {
  throw new Error('RPC_URL is not set')
}

console.log('Using addresses:')
console.log('TIMELOCK_ADDRESS:', TIMELOCK_ADDRESS)
console.log('PROTOCOL_ACCESS_MANAGER:', PROTOCOL_ACCESS_MANAGER)
console.log('SUMMER_GOVERNOR:', SUMMER_GOVERNOR)

// Gas parameters
const GAS_LIMIT = 500000n
const MAX_FEE_PER_GAS = 5000000000n // 5 gwei
const MAX_PRIORITY_FEE_PER_GAS = 1500000000n // 1.5 gwei

function createGrantGovernorRoleCalldata(governorAddress: Address): Hex {
  return encodeFunctionData({
    abi: [
      {
        name: 'grantGovernorRole',
        type: 'function',
        inputs: [{ name: 'account', type: 'address' }],
        outputs: [],
        stateMutability: 'nonpayable',
      },
    ],
    args: [governorAddress],
  })
}

async function scheduleGrantOperation(publicClient: any, walletClient: any, delay: bigint) {
  const grantCalldata = createGrantGovernorRoleCalldata(SUMMER_GOVERNOR)
  console.log('grantCalldata:', grantCalldata)

  const hasRole = await publicClient.readContract({
    address: TIMELOCK_ADDRESS,
    abi: [
      {
        name: 'hasRole',
        type: 'function',
        inputs: [
          { name: 'role', type: 'bytes32' },
          { name: 'account', type: 'address' },
        ],
        outputs: [{ type: 'bool' }],
        stateMutability: 'view',
      },
    ],
    functionName: 'hasRole',
    args: [
      '0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1', // PROPOSER_ROLE
      walletClient.account.address,
    ],
  })
  console.log('Has proposer role:', hasRole)

  const scheduleTx = encodeFunctionData({
    abi: [
      {
        name: 'schedule',
        type: 'function',
        inputs: [
          { name: 'target', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'data', type: 'bytes' },
          { name: 'predecessor', type: 'bytes32' },
          { name: 'salt', type: 'bytes32' },
          { name: 'delay', type: 'uint256' },
        ],
        outputs: [],
        stateMutability: 'nonpayable',
      },
    ],
    args: [
      PROTOCOL_ACCESS_MANAGER,
      0n,
      grantCalldata,
      '0x0000000000000000000000000000000000000000000000000000000000000000',
      '0x0000000000000000000000000000000000000000000000000000000000000000',
      delay,
    ],
  })

  const tx = await walletClient.sendTransaction({
    to: TIMELOCK_ADDRESS,
    data: scheduleTx,
    value: 0n,
    gas: GAS_LIMIT,
    maxFeePerGas: MAX_FEE_PER_GAS,
    maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS,
  })

  console.log(`Schedule transaction sent: ${tx}`)

  const receipt = await publicClient.waitForTransactionReceipt({ hash: tx })
  console.log('Transaction mined:', {
    blockNumber: receipt.blockNumber,
    gasUsed: receipt.gasUsed,
    effectiveGasPrice: receipt.effectiveGasPrice,
  })
}

async function executeGrantOperation(walletClient: any) {
  const grantCalldata = createGrantGovernorRoleCalldata(SUMMER_GOVERNOR)

  const executeTx = encodeFunctionData({
    abi: [
      {
        name: 'execute',
        type: 'function',
        inputs: [
          { name: 'target', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'data', type: 'bytes' },
          { name: 'predecessor', type: 'bytes32' },
          { name: 'salt', type: 'bytes32' },
        ],
        outputs: [],
        stateMutability: 'payable',
      },
    ],
    args: [
      PROTOCOL_ACCESS_MANAGER,
      0n,
      grantCalldata,
      '0x0000000000000000000000000000000000000000000000000000000000000000',
      '0x0000000000000000000000000000000000000000000000000000000000000000',
    ],
  })

  const tx = await walletClient.sendTransaction({
    to: TIMELOCK_ADDRESS,
    data: executeTx,
    value: 0n,
    gas: GAS_LIMIT,
    maxFeePerGas: MAX_FEE_PER_GAS,
    maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS,
  })

  console.log(`Execute transaction sent: ${tx}`)
}

async function main() {
  const publicClient = createPublicClient({
    chain: CHAIN,
    transport: http(RPC_URL),
  })

  const account = privateKeyToAccount(`0x${process.env.PRIVATE_KEY as Hex}`)
  const walletClient = createWalletClient({
    account,
    chain: CHAIN,
    transport: http(RPC_URL),
  })

  const delay = (await publicClient.readContract({
    address: TIMELOCK_ADDRESS,
    abi: [
      {
        name: 'getMinDelay',
        type: 'function',
        inputs: [],
        outputs: [{ type: 'uint256' }],
        stateMutability: 'view',
      },
    ],
    functionName: 'getMinDelay',
  })) as bigint

  await scheduleGrantOperation(publicClient, walletClient, delay)

  console.log('Waiting for timelock delay...')
  await new Promise((resolve) => setTimeout(resolve, Number(delay + 10n) * 1000))

  console.log('Executing timelock operation...')
  await executeGrantOperation(walletClient)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
