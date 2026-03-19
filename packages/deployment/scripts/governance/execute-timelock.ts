import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address, Hex, decodeEventLog, getAddress } from 'viem'

// Minimal ABI to decode the CallScheduled event and interact with Timelock
const TIMELOCK_ABI = [
  {
    anonymous: false,
    name: 'CallScheduled',
    type: 'event',
    inputs: [
      { indexed: true, name: 'id', type: 'bytes32' },
      { indexed: true, name: 'index', type: 'uint256' },
      { indexed: false, name: 'target', type: 'address' },
      { indexed: false, name: 'value', type: 'uint256' },
      { indexed: false, name: 'data', type: 'bytes' },
      { indexed: false, name: 'predecessor', type: 'bytes32' },
      { indexed: false, name: 'delay', type: 'uint256' },
    ],
  },
  {
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'datas', type: 'bytes[]' },
      { name: 'predecessor', type: 'bytes32' },
      { name: 'salt', type: 'bytes32' },
    ],
    name: 'executeBatch',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
] as const

async function main() {
  const { txHash } = await prompts({
    type: 'text',
    name: 'txHash',
    message: 'Enter the transaction hash where the calls were scheduled:',
    validate: (value: string) => (value.startsWith('0x') && value.length === 66) || 'Invalid hash',
  })

  const publicClient = await hre.viem.getPublicClient()
  const [deployer] = await hre.viem.getWalletClients()

  console.log(kleur.cyan(`\nFetching transaction receipt...`))
  const receipt = await publicClient.getTransactionReceipt({ hash: txHash as Hex })

  // 1. Extract scheduled calls from logs
  const scheduledCalls: any[] = []
  let predecessor: Hex = '0x0000000000000000000000000000000000000000000000000000000000000000'
  let timelockAddress = getAddress(receipt.to!)

  for (const log of receipt.logs) {
    try {
      const event = decodeEventLog({
        abi: TIMELOCK_ABI,
        eventName: 'CallScheduled',
        data: log.data,
        topics: log.topics,
      })

      scheduledCalls.push({
        index: Number(event.args.index),
        target: event.args.target,
        value: event.args.value,
        data: event.args.data,
      })
      predecessor = event.args.predecessor
      timelockAddress
    } catch (e) {
      // Not a CallScheduled event, skip
    }
  }

  if (scheduledCalls.length === 0) {
    throw new Error('No CallScheduled events found in this transaction.')
  }

  // Sort by index to ensure correct batch order
  scheduledCalls.sort((a, b) => a.index - b.index)

  const targets = scheduledCalls.map((c) => c.target)
  const values = scheduledCalls.map((c) => c.value)
  const datas = scheduledCalls.map((c) => c.data)

  // 2. Identify the Salt (Note: In OpenZeppelin, the salt isn't in the event,
  // but usually you use the same salt provided during the schedule call)
  const { salt } = await prompts({
    type: 'text',
    name: 'salt',
    message: 'Enter the salt used during scheduling (hex):',
    initial: '0x0aa540ec23875dea6c5bf193abb65de366d73fb62071e67ee0ed076bd5ce61b8', // From your logs
  })

  console.log(kleur.yellow(`\nTimelock: ${timelockAddress}`))
  console.log(kleur.yellow(`Batch Size: ${scheduledCalls.length} actions`))

  const { confirm } = await prompts({
    type: 'confirm',
    name: 'confirm',
    message: `Execute this batch on ${hre.network.name}?`,
    initial: true,
  })

  if (!confirm) return

  // 3. Execute
  const timelock = await hre.viem.getContractAt('TimelockController' as any, timelockAddress)

  console.log(kleur.cyan('Sending execution transaction...'))

  const hash = await deployer.writeContract({
    address: timelockAddress,
    abi: TIMELOCK_ABI,
    functionName: 'executeBatch',
    args: [targets, values, datas, predecessor, salt as Hex],
    gas: 5000000n,
  })

  console.log(kleur.green(`Transaction sent: ${hash}`))
  const execReceipt = await publicClient.waitForTransactionReceipt({ hash })
  console.log(kleur.green(`Success! Mined in block ${execReceipt.blockNumber}`))
}

main().catch((err) => {
  console.error(kleur.red('Execution failed:'), err)
  process.exitCode = 1
})
