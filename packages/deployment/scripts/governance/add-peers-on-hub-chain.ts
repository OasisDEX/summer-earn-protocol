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
import { base } from 'viem/chains'

dotenv.config()

// Validate required environment variables
if (!process.env.BASE_SUMMER_GOVERNOR_ADDRESS)
  throw new Error('BASE_SUMMER_GOVERNOR_ADDRESS not set')
if (!process.env.ARB_SUMMER_GOVERNOR_ADDRESS) throw new Error('ARB_SUMMER_GOVERNOR_ADDRESS not set')
if (!process.env.ARB_ENDPOINT_ID) throw new Error('ARB_ENDPOINT_ID not set')
if (!process.env.BASE_TIMELOCK_ADDRESS) throw new Error('BASE_TIMELOCK_ADDRESS not set')
if (!process.env.PRIVATE_KEY) throw new Error('PRIVATE_KEY not set')
if (!process.env.RPC_URL) throw new Error('RPC_URL not set')

// Contract addresses
const HUB_SUMMER_GOVERNOR_ADDRESS = process.env.BASE_SUMMER_GOVERNOR_ADDRESS as Address
const ARB_SUMMER_GOVERNOR_ADDRESS = process.env.ARB_SUMMER_GOVERNOR_ADDRESS as Address
const ARB_ENDPOINT_ID = process.env.ARB_ENDPOINT_ID as string // LayerZero chain ID for Arbitrum
const BASE_TIMELOCK_ADDRESS = process.env.BASE_TIMELOCK_ADDRESS as Address

function createSetPeerCalldata(peerAddress: Address, endpointId: string): Hex {
  const peerAddressAsBytes32 = `0x${peerAddress.slice(2).padEnd(64, '0')}` as Hex
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
  const setPeerCalldata = createSetPeerCalldata(ARB_SUMMER_GOVERNOR_ADDRESS, ARB_ENDPOINT_ID)
  console.log('setPeerCalldata:', setPeerCalldata)

  const hasRole = await publicClient.readContract({
    address: BASE_TIMELOCK_ADDRESS,
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
      HUB_SUMMER_GOVERNOR_ADDRESS,
      0n,
      setPeerCalldata,
      '0x0000000000000000000000000000000000000000000000000000000000000000',
      '0x0000000000000000000000000000000000000000000000000000000000000000',
      delay,
    ],
  })

  const tx = await walletClient.sendTransaction({
    to: BASE_TIMELOCK_ADDRESS,
    data: scheduleTx,
    value: 0n,
    gasLimit: 1000000n,
    maxFeePerGas: 100000000000n, // 100 gwei
    maxPriorityFeePerGas: 10000000000n, // 10 gwei
  })

  console.log(`Schedule transaction sent: ${tx}`)
}

async function executeSetPeerOperation(walletClient: any) {
  const setPeerCalldata = createSetPeerCalldata(ARB_SUMMER_GOVERNOR_ADDRESS, ARB_ENDPOINT_ID)

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
      HUB_SUMMER_GOVERNOR_ADDRESS,
      0n,
      setPeerCalldata,
      '0x0000000000000000000000000000000000000000000000000000000000000000',
      '0x0000000000000000000000000000000000000000000000000000000000000000',
    ],
  })

  const tx = await walletClient.sendTransaction({
    to: BASE_TIMELOCK_ADDRESS,
    data: executeTx,
    value: 0n,
    gasLimit: 1000000n,
  })

  console.log(`Execute transaction sent: ${tx}`)
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

  const delay = (await publicClient.readContract({
    address: BASE_TIMELOCK_ADDRESS,
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
