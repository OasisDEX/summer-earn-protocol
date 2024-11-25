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
const GOVERNOR_ADDRESS = process.env.ARB_SUMMER_GOVERNOR_ADDRESS as Address
const PEER_GOVERNOR_ADDRESS = process.env.BASE_SUMMER_GOVERNOR_ADDRESS as Address
const PEER_ENDPOINT_ID = process.env.BASE_ENDPOINT_ID as string
const TIMELOCK_ADDRESS = process.env.ARB_TIMELOCK_ADDRESS as Address
const RPC_URL = process.env.ARBITRUM_RPC_URL as string
const CHAIN = arbitrum
// const CHAIN = base;

// Verify addresses and endpoint ID are not empty
if (!GOVERNOR_ADDRESS) {
  throw new Error('GOVERNOR_ADDRESS is not set')
}

if (!PEER_GOVERNOR_ADDRESS) {
  throw new Error('PEER_GOVERNOR_ADDRESS is not set')
}

if (!PEER_ENDPOINT_ID) {
  throw new Error('PEER_ENDPOINT_ID is not set')
}

if (!TIMELOCK_ADDRESS) {
  throw new Error('TIMELOCK_ADDRESS is not set')
}

if (!RPC_URL) {
  throw new Error('RPC_URL is not set')
}

console.log('Using addresses:')
console.log('GOVERNOR_ADDRESS:', GOVERNOR_ADDRESS)
console.log('PEER_GOVERNOR_ADDRESS:', PEER_GOVERNOR_ADDRESS)
console.log('PEER_ENDPOINT_ID:', PEER_ENDPOINT_ID)
console.log('TIMELOCK_ADDRESS:', TIMELOCK_ADDRESS)

// Reduce gas parameters
const GAS_LIMIT = 200000n // Reduced from 300000n
const MAX_FEE_PER_GAS = 1500000000n // 1.5 gwei (reduced from 150 gwei)
const MAX_PRIORITY_FEE_PER_GAS = 1500000000n // 1.5 gwei (reduced from 15 gwei)

function createSetPeerCalldata(peerAddress: Address, endpointId: string): Hex {
  const peerAddressAsBytes32 = `0x000000000000000000000000${peerAddress.slice(2)}` as Hex
  console.log('peerAddressAsBytes32:', peerAddressAsBytes32)
  return encodeFunctionData({
    abi: [
      {
        name: 'setPeer',
        type: 'function',
        inputs: [
          { name: '_eid', type: 'uint32' },
          { name: '_peer', type: 'bytes32' },
        ],
        outputs: [],
        stateMutability: 'nonpayable',
      },
    ],
    args: [Number(endpointId), peerAddressAsBytes32],
  })
}

async function scheduleSetPeerOperation(publicClient: any, walletClient: any, delay: bigint) {
  const setPeerCalldata = createSetPeerCalldata(PEER_GOVERNOR_ADDRESS, PEER_ENDPOINT_ID)
  console.log('setPeerCalldata:', setPeerCalldata)

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
      GOVERNOR_ADDRESS,
      0n,
      setPeerCalldata,
      '0x0000000000000000000000000000000000000000000000000000000000000000',
      '0x0000000000000000000000000000000000000000000000000000000000000000',
      delay,
    ],
  })

  const tx = await walletClient.sendTransaction({
    to: TIMELOCK_ADDRESS,
    data: scheduleTx,
    value: 0n,
    gas: GAS_LIMIT, // Use higher gas limit
    maxFeePerGas: MAX_FEE_PER_GAS,
    maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS,
  })

  console.log(`Schedule transaction sent: ${tx}`)

  // Add transaction receipt logging
  const receipt = await publicClient.waitForTransactionReceipt({ hash: tx })
  console.log('Transaction mined:', {
    blockNumber: receipt.blockNumber,
    gasUsed: receipt.gasUsed,
    effectiveGasPrice: receipt.effectiveGasPrice,
  })
}

async function executeSetPeerOperation(walletClient: any) {
  const setPeerCalldata = createSetPeerCalldata(PEER_GOVERNOR_ADDRESS, PEER_ENDPOINT_ID)

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
      GOVERNOR_ADDRESS,
      0n,
      setPeerCalldata,
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

  await scheduleSetPeerOperation(publicClient, walletClient, delay)

  console.log('Waiting for timelock delay...')
  await new Promise((resolve) => setTimeout(resolve, Number(delay + 10n) * 1000))

  console.log('Executing timelock operation...')
  await executeSetPeerOperation(walletClient)
}

main()
