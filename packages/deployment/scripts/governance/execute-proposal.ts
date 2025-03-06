import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address, parseAbi } from 'viem'
import { HUB_CHAIN_NAME } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { hashDescription } from '../helpers/hash-description'
import { promptForConfigType } from '../helpers/prompt-helpers'
import { ProposalData, loadProposal } from '../helpers/proposal-helpers'
import { sleep } from '../helpers/utils'

enum ProposalState {
  Pending,
  Active,
  Canceled,
  Defeated,
  Succeeded,
  Queued,
  Expired,
  Executed,
}

async function promptForProposalId() {
  const response = await prompts({
    type: 'text',
    name: 'proposalId',
    message: 'Enter the proposal ID:',
    validate: (value) => {
      // Accept hex strings with or without 0x prefix
      const hexPattern = /^(0x)?[0-9a-fA-F]+$/i
      return hexPattern.test(value) || 'Please enter a valid hex string'
    },
  })

  // Normalize to remove 0x prefix if present
  return response.proposalId.replace(/^0x/i, '').toLowerCase()
}

async function promptForExecutionValue() {
  const response = await prompts({
    type: 'text',
    name: 'executionValue',
    message: 'Enter the total ETH value in wei to send with execution:',
    initial: '0',
    validate: (value) => !isNaN(Number(value)) || 'Please enter a valid number',
  })
  return BigInt(response.executionValue)
}

async function executeStandardProposal(
  proposal: ProposalData,
  proposalId: string,
  governorAddress: Address,
) {
  const { targets, values, calldatas, description } = proposal

  // Get execution value
  const executionValue = await promptForExecutionValue()

  // Compute description hash
  const descriptionHash = hashDescription(description)
  console.log('descriptionHash', descriptionHash)

  const publicClient = await hre.viem.getPublicClient()
  // Create a contract instance
  const governor = await hre.viem.getContractAt('SummerGovernor' as string, governorAddress)

  console.log('Checking proposal state...')

  while (true) {
    const state = await governor.read.state([BigInt(proposalId)])
    console.log(`Current proposal state: ${ProposalState[state as number]}`)

    if (state === ProposalState.Queued) {
      console.log(kleur.green('Proposal is ready for execution!'))
      break
    } else if (state === ProposalState.Executed) {
      console.log(kleur.yellow('Proposal has already been executed.'))
      return
    } else if (
      [
        ProposalState.Canceled,
        ProposalState.Defeated,
        ProposalState.Expired,
        ProposalState.Pending,
      ].includes(state as ProposalState)
    ) {
      console.log(kleur.red('Proposal cannot be executed due to its current state.'))
      return
    }

    console.log('Waiting 10 seconds before checking again...')
    await sleep(10000)
  }

  try {
    console.log('\nExecuting proposal with:')
    console.log('Governor:', governorAddress)
    console.log('Targets:', targets)
    console.log('Values:', values)
    console.log('Execution Value:', executionValue)
    console.log(`Calldatas: (${calldatas.length} items)`)
    for (let i = 0; i < Math.min(calldatas.length, 3); i++) {
      console.log(`  ${i + 1}. ${calldatas[i].substring(0, 50)}...`)
    }
    if (calldatas.length > 3) {
      console.log(`  ... and ${calldatas.length - 3} more`)
    }
    console.log(
      'Description:',
      description.substring(0, 100) + (description.length > 100 ? '...' : ''),
    )
    console.log('Description Hash:', descriptionHash)

    // Confirm execution
    const confirmResponse = await prompts({
      type: 'confirm',
      name: 'proceed',
      message: 'Do you want to execute this proposal?',
      initial: false,
    })

    if (!confirmResponse.proceed) {
      console.log(kleur.yellow('Execution cancelled.'))
      return
    }

    // Execute the proposal
    const tx = await governor.write.execute([targets, values, calldatas, descriptionHash], {
      value: executionValue,
      gasLimit: 1000000,
    })

    console.log(kleur.green('Proposal execution submitted. Transaction hash:'), tx)

    const receipt = await publicClient.waitForTransactionReceipt({ hash: tx })
    console.log(kleur.green('Execute transaction mined. Block number:'), receipt.blockNumber)
  } catch (error: any) {
    console.error(kleur.red('Error executing proposal:'), error)
    if (error.reason) {
      console.error(kleur.red('Error reason:'), error.reason)
    }
  }
}

async function executeCrossChainProposal(proposal: ProposalData) {
  if (!proposal.crossChainExecution?.targetChain) {
    console.error(kleur.red('No cross-chain execution details found in proposal.'))
    return
  }

  const targetChain = proposal.crossChainExecution.targetChain

  // Check that we have the required arrays
  if (
    !targetChain.targets ||
    !targetChain.values ||
    !targetChain.datas ||
    !Array.isArray(targetChain.targets) ||
    !Array.isArray(targetChain.values) ||
    !Array.isArray(targetChain.datas)
  ) {
    console.error(kleur.red('Missing or invalid target chain execution arrays.'))
    return
  }

  // Make sure arrays have at least one element
  if (
    targetChain.targets.length === 0 ||
    targetChain.values.length === 0 ||
    targetChain.datas.length === 0
  ) {
    console.error(kleur.red('Target chain execution arrays cannot be empty.'))
    return
  }

  console.log(kleur.cyan('\nExecuting cross-chain proposal on target chain...'))

  // Prompt for operation ID (not proposal ID)
  const { operationId } = await prompts([
    {
      type: 'text',
      name: 'operationId',
      message: 'Enter the operation ID (from CallScheduled event):',
      validate: (value) =>
        /^0x[a-fA-F0-9]{64}$/.test(value) ? true : 'Please enter a valid bytes32 hash',
    },
  ])

  console.log(kleur.yellow(`Using operation ID: ${operationId}`))

  // Display targets, values, and data from proposal
  console.log(kleur.yellow(`Targets (${targetChain.targets.length}):`))
  targetChain.targets.forEach((target, i) => {
    console.log(kleur.yellow(`  ${i + 1}. ${target}`))
  })

  console.log(kleur.yellow(`Values (${targetChain.values.length}):`))
  targetChain.values.forEach((value, i) => {
    console.log(kleur.yellow(`  ${i + 1}. ${value}`))
  })

  console.log(kleur.yellow(`Data (${targetChain.datas.length}):`))
  targetChain.datas.forEach((data, i) => {
    const shortened = data.length > 50 ? `${data.substring(0, 47)}...` : data
    console.log(kleur.yellow(`  ${i + 1}. ${shortened}`))
  })

  console.log(kleur.yellow(`Delay: ${targetChain.delay || 'Not specified'}`))

  // Get config for the current network
  const useBummerConfig = await promptForConfigType()
  const network = hre.network.name
  const config = getConfigByNetwork(
    network,
    { common: true, gov: true, core: true },
    useBummerConfig,
  )

  // Get the timelock address from config
  const timelockAddress = config.deployedContracts.gov.timelock.address as Address
  console.log(kleur.yellow(`Timelock address: ${timelockAddress}`))

  const publicClient = await hre.viem.getPublicClient()

  // Convert all values to the required format
  const targets = targetChain.targets.map((t) => t as Address)
  const values = targetChain.values.map((v) => BigInt(v))
  const payloads = targetChain.datas.map((d) => d as `0x${string}`)

  // Format predecessor properly - ensure it's a 0x-prefixed 32-byte value
  let predecessorBytes: `0x${string}` =
    '0x0000000000000000000000000000000000000000000000000000000000000000'
  if (targetChain.predecessor) {
    // Remove 0x prefix if present
    const cleanPredecessor = targetChain.predecessor.replace(/^0x/i, '')
    // Add 0x prefix back
    predecessorBytes = `0x${cleanPredecessor}` as `0x${string}`
  }

  // Get salt from on-chain event
  const saltEvents = await publicClient.getLogs({
    address: timelockAddress,
    event: parseAbi(['event CallSalt(bytes32 indexed id, bytes32 salt)'])[0],
    args: {
      id: operationId as `0x${string}`,
    },
    fromBlock: 'earliest',
  })

  console.log(kleur.yellow(`Salt events found: ${saltEvents.length}`))

  let salt: `0x${string}`
  if (saltEvents.length === 0) {
    console.log(kleur.yellow('Trying alternative method to find the salt...'))

    // Try to get all logs for the timelock and filter manually
    const allTimelockLogs = await publicClient.getLogs({
      address: timelockAddress,
      fromBlock: 'earliest',
    })

    console.log(kleur.yellow(`Found ${allTimelockLogs.length} total logs for timelock`))

    // Try to match by topic signature for CallSalt
    const callSaltSignature = '0x56c32da9b30915b2c727d181c11d28241e161dc97d0eee5684d200a3b56cedad' // keccak256("CallSalt(bytes32,bytes32)")
    const relevantLogs = allTimelockLogs.filter(
      (log) => log.topics[0] === callSaltSignature && log.topics[1] === operationId,
    )

    console.log(kleur.yellow(`Found ${relevantLogs.length} matching CallSalt logs`))

    if (relevantLogs.length > 0) {
      // Parse the salt from the log data
      const saltFromLogs = relevantLogs[0].data as `0x${string}`
      console.log(kleur.green(`Found salt from logs: ${saltFromLogs}`))

      // Override the earlier undefined salt
      salt = saltFromLogs
    }
  } else {
    console.log(kleur.green(`Found salt from event: ${saltEvents[0]?.args.salt}`))
  }

  salt =
    saltEvents[0]?.args.salt ??
    ('0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`)

  console.log(kleur.yellow(`Using salt: ${salt}`))

  try {
    // Create a contract instance for the timelock
    const timelock = await hre.viem.getContractAt(
      'SummerTimelockController' as string,
      timelockAddress,
    )

    // Verify operation is ready
    const isReady = await timelock.read.isOperationReady([operationId as `0x${string}`])

    if (!isReady) {
      console.error(
        kleur.red(
          'Operation is not ready for execution. The timelock delay may not have passed yet.',
        ),
      )
      return
    }

    const isDone = await timelock.read.isOperationDone([operationId as `0x${string}`])

    if (isDone) {
      console.log(kleur.yellow('This operation has already been executed.'))
      return
    }

    // Confirm execution
    const confirmResponse = await prompts({
      type: 'confirm',
      name: 'proceed',
      message: 'Do you want to execute this cross-chain proposal?',
      initial: false,
    })

    if (!confirmResponse.proceed) {
      console.log(kleur.yellow('Execution cancelled.'))
      return
    }

    console.log(kleur.green('Executing batch operation...'))

    // Execute the batch proposal
    const hash = await timelock.write.executeBatch(
      [targets, values, payloads, predecessorBytes, salt],
      {
        gas: 1200000n,
        maxFeePerGas: (await publicClient.getGasPrice()) * 2n,
      },
    )

    console.log(kleur.green('Execution submitted. Transaction hash:'), hash)

    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    console.log(kleur.green('Execution transaction mined. Block number:'), receipt.blockNumber)
  } catch (error: any) {
    console.error(kleur.red('Error executing proposal:'), error)
    if (error.cause) {
      console.error(kleur.red('Error cause:'), error.cause)
      if (error.cause.data) {
        console.error(kleur.red('Error data:'), error.cause.data)
      }
    }
  }
}

async function main() {
  console.log(kleur.cyan().bold('=== Lazy Summer Protocol Governance Proposal Execution ==='))
  console.log('')

  // Get config for current network
  const network = hre.network.name
  console.log(kleur.yellow(`Using network: ${network}`))

  // Load proposal details from file using the imported function
  const proposal = await loadProposal()
  if (!proposal) {
    console.log(kleur.red('No proposal selected. Exiting.'))
    return
  }

  // Check if this is a cross-chain proposal
  const isCrossChain = !!proposal.crossChainExecution

  if (isCrossChain) {
    console.log(kleur.cyan('This is a cross-chain proposal.'))

    // Check if the current network matches the target chain
    const currentNetwork = network.toLowerCase()

    if (currentNetwork !== HUB_CHAIN_NAME) {
      // We're on the target chain, execute the cross-chain proposal
      await executeCrossChainProposal(proposal)
    } else {
      // We're on the hub chain, use the stored proposal ID if available or prompt for it
      console.log(kleur.cyan('You are on the hub chain. Executing the hub chain proposal...'))

      // Add prompt for bummer config selection
      const useBummerConfig = await promptForConfigType()
      const config = getConfigByNetwork(
        network,
        { common: true, gov: true, core: true },
        useBummerConfig,
      )

      // Get the governor address from config
      const governorAddress = config.deployedContracts.gov.summerGovernor.address as Address
      console.log(kleur.yellow(`Governor address: ${governorAddress}`))

      // Get proposal ID
      const proposalId = await promptForProposalId()

      // Execute the standard proposal
      await executeStandardProposal(proposal, proposalId, governorAddress)
    }
  } else {
    // Standard single-chain proposal
    console.log(kleur.cyan('This is a standard (non-cross-chain) proposal.'))

    // Add prompt for bummer config selection
    const useBummerConfig = await promptForConfigType()
    const config = getConfigByNetwork(
      network,
      { common: true, gov: true, core: true },
      useBummerConfig,
    )

    // Get the governor address from config
    const governorAddress = config.deployedContracts.gov.summerGovernor.address as Address
    console.log(kleur.yellow(`Governor address: ${governorAddress}`))

    // Prompt for proposal ID
    const proposalId = await promptForProposalId()

    // Execute the standard proposal
    await executeStandardProposal(proposal, proposalId, governorAddress)
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(kleur.red('Error running script:'), error)
    process.exit(1)
  })
