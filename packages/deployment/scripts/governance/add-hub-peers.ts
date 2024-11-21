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

// Contract addresses
const BASE_SUMMER_GOVERNOR_ADDRESS = process.env.BASE_SUMMER_GOVERNOR_ADDRESS as Address
const ARB_SUMMER_GOVERNOR_ADDRESS = process.env.ARB_SUMMER_GOVERNOR_ADDRESS as Address
const ARB_CHAIN_ID = process.env.ARB_CHAIN_ID as string // LayerZero chain ID for Arbitrum
const BASE_TIMELOCK_ADDRESS = process.env.BASE_TIMELOCK_ADDRESS as Address

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

  // Convert Arbitrum governor address to bytes32
  const peerAddressAsBytes32 = `0x${ARB_SUMMER_GOVERNOR_ADDRESS.slice(2).padEnd(64, '0')}` as Hex

  // Prepare the setPeer call
  const setPeerCalldata = encodeFunctionData({
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
    args: [Number(ARB_CHAIN_ID), peerAddressAsBytes32],
  })

  // Prepare the timelock schedule call
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

  const scheduleTx = encodeFunctionData({
    abi: [
      {
        name: 'schedule',
        type: 'function',
        inputs: [
          { name: 'target', type: 'address' },
          { name: 'data', type: 'bytes' },
          { name: 'eta', type: 'uint256' },
        ],
        outputs: [],
        stateMutability: 'nonpayable',
      },
    ],
    args: [BASE_TIMELOCK_ADDRESS, setPeerCalldata, delay],
  })

  const tx = await walletClient.sendTransaction({
    to: BASE_TIMELOCK_ADDRESS,
    data: scheduleTx,
    value: 0n,
    gasLimit: 1000000n,
    gasPrice: 1000000000n,
  })

  console.log(`Transaction sent: ${tx.hash}`)
}

main()
