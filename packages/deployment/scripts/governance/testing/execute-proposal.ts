import prompts from 'prompts'
import { Address, parseAbi } from 'viem'
import { promptForChain } from '../../helpers/chain-prompt'
import { hashDescription } from '../../helpers/hash-description'
import { sleep } from '../../helpers/utils'
import { createClients } from '../../helpers/wallet-helper'

const governorAbi = parseAbi([
  'function state(uint256 proposalId) view returns (uint8)',
  'function execute(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) public returns (uint256)',
])

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

async function promptForProposalDetails() {
  const response = await prompts([
    {
      type: 'text',
      name: 'proposalId',
      message: 'Enter the proposal ID:',
      validate: (value) => !isNaN(Number(value)) || 'Please enter a valid number',
    },
    {
      type: 'list',
      name: 'targets',
      message: 'Enter the target addresses (comma-separated):',
      separator: ',',
      validate: (value) => {
        const addresses = value.split(',').map((addr: string) => addr.trim())
        return (
          addresses.every((addr: string) => addr.startsWith('0x')) ||
          'All addresses must start with 0x'
        )
      },
    },
    {
      type: 'list',
      name: 'values',
      message: 'Enter the values in wei (comma-separated, use 0 if no ETH needs to be sent):',
      separator: ',',
      initial: '0',
      validate: (value) => {
        const values = value.split(',').map((val: string) => val.trim())
        return values.every((val: string) => !isNaN(Number(val))) || 'All values must be numbers'
      },
    },
    {
      type: 'text',
      name: 'executionValue',
      message: 'Enter the total ETH value in wei to send with execution (in wei):',
      initial: '0',
      validate: (value) => !isNaN(Number(value)) || 'Please enter a valid number',
    },
    {
      type: 'list',
      name: 'calldatas',
      message: 'Enter the calldatas (comma-separated):',
      separator: ',',
      validate: (value) => {
        const calldatas = value.split(',').map((data: string) => data.trim())
        return (
          calldatas.every((data: string) => data.startsWith('0x')) ||
          'All calldata must start with 0x'
        )
      },
    },
    {
      type: 'text',
      name: 'description',
      message: 'Enter the proposal description:',
    },
  ])

  return {
    proposalId: BigInt(response.proposalId),
    targets: response.targets as `0x${string}`[],
    values: response.values.map((v: string) => BigInt(v)),
    executionValue: BigInt(response.executionValue),
    calldatas: response.calldatas as `0x${string}`[],
    description: response.description,
  }
}

async function main() {
  const { config: hubConfig, chain, rpcUrl } = await promptForChain('Select chain:')
  const { publicClient, walletClient } = createClients(chain, rpcUrl)

  const governorResponse = await prompts({
    type: 'text',
    name: 'governorAddress',
    message: 'Enter the governor contract address:',
    initial: hubConfig.deployedContracts.gov?.summerGovernor?.address || '',
    validate: (value) => value.startsWith('0x') || 'Address must start with 0x',
  })

  const governorAddress = governorResponse.governorAddress as Address
  const { proposalId, targets, values, executionValue, calldatas, description } =
    await promptForProposalDetails()

  console.log('Checking proposal state...')

  while (true) {
    const state = await publicClient.readContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'state',
      args: [proposalId],
    })

    console.log(`Current proposal state: ${ProposalState[state]}`)

    if (state === ProposalState.Queued) {
      console.log('Proposal is ready for execution!')
      break
    } else if (state === ProposalState.Executed) {
      console.log('Proposal has already been executed.')
      return
    } else if (
      [
        ProposalState.Canceled,
        ProposalState.Defeated,
        ProposalState.Expired,
        ProposalState.Pending,
      ].includes(state)
    ) {
      console.log('Proposal cannot be executed due to its current state.')
      return
    }

    console.log('Waiting 10 seconds before checking again...')
    await sleep(10000)
  }

  try {
    const descriptionHash = hashDescription(description)

    console.log('\nExecuting proposal with:')
    console.log('Governor:', governorAddress)
    console.log('Targets:', targets)
    console.log('Values:', values)
    console.log('Execution Value:', executionValue)
    console.log('Calldatas:', calldatas)
    console.log('Description:', description)
    console.log('Description Hash:', descriptionHash)

    const hash = await walletClient.writeContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'execute',
      args: [targets, values, calldatas, descriptionHash],
      gas: 1000000n,
      maxFeePerGas: await publicClient.getGasPrice(),
      value: executionValue,
    })

    console.log('Proposal execution submitted. Transaction hash:', hash)

    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    console.log('Execute transaction mined. Block number:', receipt.blockNumber)
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
