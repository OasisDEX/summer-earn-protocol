import dotenv from 'dotenv'
import { Address, createPublicClient, createWalletClient, Hex, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { base } from 'viem/chains'

dotenv.config()

const TIMELOCK_ADDRESS = process.env.BASE_TIMELOCK_ADDRESS as Address

const timelockAbi = [
  {
    inputs: [{ name: 'id', type: 'bytes32' }],
    name: 'cancel',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ name: 'id', type: 'bytes32' }],
    name: 'isOperationPending',
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ name: 'id', type: 'bytes32' }],
    name: 'isOperationReady',
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ name: 'id', type: 'bytes32' }],
    name: 'isOperationDone',
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

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

  const proposalIdBytes32 =
    `0x178ce2c25712f08c9eaa8a1eaba879ec970a952b5877df1422a2f779312edb6f` as Hex
  console.log('Proposal ID (bytes32):', proposalIdBytes32)
  try {
    console.log('Checking operation state...')

    const isPending = await publicClient.readContract({
      address: TIMELOCK_ADDRESS,
      abi: timelockAbi,
      functionName: 'isOperationPending',
      args: [proposalIdBytes32],
    })

    const isReady = await publicClient.readContract({
      address: TIMELOCK_ADDRESS,
      abi: timelockAbi,
      functionName: 'isOperationReady',
      args: [proposalIdBytes32],
    })

    const isDone = await publicClient.readContract({
      address: TIMELOCK_ADDRESS,
      abi: timelockAbi,
      functionName: 'isOperationDone',
      args: [proposalIdBytes32],
    })

    console.log('Operation state:', {
      isPending,
      isReady,
      isDone,
    })

    if (!isPending) {
      console.error('Operation is not in pending state and cannot be cancelled')
      return
    }

    console.log('Cancelling timelock operation...')

    const hash = await walletClient.writeContract({
      address: TIMELOCK_ADDRESS,
      abi: timelockAbi,
      functionName: 'cancel',
      args: [proposalIdBytes32],
    })

    console.log('Cancel transaction submitted:', hash)

    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    console.log('Cancel transaction mined in block:', receipt.blockNumber)
  } catch (error: any) {
    console.error('Error:', error)
    if (error.cause) {
      console.error('Error cause:', error.cause)
    }
  }
}

main().catch(console.error)
