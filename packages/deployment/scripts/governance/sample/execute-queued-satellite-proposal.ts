import prompts from 'prompts'
import { Address, parseAbi } from 'viem'
import { promptForChain } from '../../helpers/chain-prompt'
import { createClients } from '../../helpers/wallet-helper'

const timelockAbi = parseAbi([
  'function execute(address target, uint256 value, bytes calldata payload, bytes32 predecessor, bytes32 salt) public payable',
  'function executeBatch(address[] calldata targets, uint256[] calldata values, bytes[] calldata payloads, bytes32 predecessor, bytes32 salt) public payable',
  'function isOperationReady(bytes32 id) public view returns (bool)',
  'function isOperationDone(bytes32 id) public view returns (bool)',
  'function hashOperationBatch(address[] calldata targets, uint256[] calldata values, bytes[] calldata payloads, bytes32 predecessor, bytes32 salt) public pure returns (bytes32)',
])

async function main() {
  const { config: targetConfig, chain, rpcUrl } = await promptForChain('Select the target chain:')

  const { publicClient, walletClient } = createClients(chain, rpcUrl)

  // Get timelock address from config
  const timelockAddress = targetConfig.deployedContracts.gov.timelock.address as Address

  const { operationId } = await prompts([
    {
      type: 'text',
      name: 'operationId',
      message: 'Enter the operation ID (from CallScheduled event):',
      validate: (value) =>
        /^0x[a-fA-F0-9]{64}$/.test(value) ? true : 'Please enter a valid bytes32 hash',
    },
  ])

  // Get all CallScheduled events for this operation ID
  const scheduledEvents = await publicClient.getLogs({
    address: timelockAddress,
    event: parseAbi([
      'event CallScheduled(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data, bytes32 predecessor, uint256 delay)',
    ])[0],
    args: {
      id: operationId as `0x${string}`,
    },
    fromBlock: 'earliest',
  })

  if (scheduledEvents.length === 0) {
    console.error('No CallScheduled events found for this operation ID')
    return
  }

  // Get salt from CallSalt event
  const saltEvents = await publicClient.getLogs({
    address: timelockAddress,
    event: parseAbi(['event CallSalt(bytes32 indexed id, bytes32 salt)'])[0],
    args: {
      id: operationId as `0x${string}`,
    },
    fromBlock: 'earliest',
  })

  const salt =
    saltEvents[0]?.args.salt ?? '0x0000000000000000000000000000000000000000000000000000000000000000'

  // Prepare batch parameters
  const targets: Address[] = []
  const values: bigint[] = []
  const payloads: `0x${string}`[] = []
  let predecessor =
    '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`

  // Sort events by index and extract parameters
  scheduledEvents
    .sort((a, b) => Number(a.args.index) - Number(b.args.index))
    .forEach((event) => {
      targets.push(event.args.target as Address)
      values.push(event.args.value!)
      payloads.push(event.args.data as `0x${string}`)
      predecessor = event.args.predecessor as `0x${string}`
    })

  // Verify operation is ready
  const isReady = await publicClient.readContract({
    address: timelockAddress,
    abi: timelockAbi,
    functionName: 'isOperationReady',
    args: [operationId as `0x${string}`],
  })

  if (!isReady) {
    console.error(
      'Operation is not ready for execution. The timelock delay may not have passed yet.',
    )
    return
  }

  const isDone = await publicClient.readContract({
    address: timelockAddress,
    abi: timelockAbi,
    functionName: 'isOperationDone',
    args: [operationId as `0x${string}`],
  })

  if (isDone) {
    console.error('Operation has already been executed.')
    return
  }

  try {
    console.log('Executing batch operation...')
    console.log('Operation ID:', operationId)
    console.log('Targets:', targets)
    console.log('Values:', values)
    console.log('Payloads:', payloads)
    console.log('Predecessor:', predecessor)
    console.log('Salt:', salt)

    // Execute the batch proposal
    const hash = await walletClient.writeContract({
      address: timelockAddress,
      abi: timelockAbi,
      functionName: 'executeBatch',
      args: [targets, values, payloads, predecessor, salt],
      gas: 500000n,
      maxFeePerGas: await publicClient.getGasPrice(),
    })

    console.log('Execution submitted. Transaction hash:', hash)

    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    console.log('Execution transaction mined. Block number:', receipt.blockNumber)
  } catch (error: any) {
    console.error('Error executing proposal:', error)
    if (error.cause) {
      console.error('Error cause:', error.cause)
      if (error.cause.data) {
        console.error('Error data:', error.cause.data)
      }
    }
  }
}

main().catch(console.error)
