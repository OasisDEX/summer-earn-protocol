import prompts from 'prompts'
import { Address, parseAbi } from 'viem'
import { promptForChain } from '../../helpers/chain-prompt'
import { hashDescription } from '../../helpers/hash-description'
import { createClients } from '../../helpers/wallet-helper'

// Governor ABI (only the needed functions)
const governorAbi = parseAbi([
  'function proposalNeedsQueuing(uint256 proposalId) public view returns (bool)',
  'function queue(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) public returns (uint256)',
  'function hashProposal(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) public pure returns (uint256)',
])

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
      message: 'Enter the values (comma-separated):',
      separator: ',',
      initial: '0',
      validate: (value) => {
        const values = value.split(',').map((val: string) => val.trim())
        return values.every((val: string) => !isNaN(Number(val))) || 'All values must be numbers'
      },
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
    targets: response.targets,
    values: response.values.map((v: string) => BigInt(v)),
    calldatas: response.calldatas,
    description: response.description,
  }
}

async function main() {
  // Get chain configuration through prompt
  const { config: hubConfig, chain, rpcUrl } = await promptForChain('Select the hub chain:')

  const { publicClient, walletClient } = createClients(chain, rpcUrl)

  // Get the proposal details through prompts
  const { proposalId, targets, values, calldatas, description } = await promptForProposalDetails()

  const HUB_GOVERNOR_ADDRESS = hubConfig.deployedContracts.gov.summerGovernor.address as Address

  try {
    // Check if the proposal needs queuing
    const needsQueuing = await publicClient.readContract({
      address: HUB_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'proposalNeedsQueuing',
      args: [proposalId],
    })

    if (!needsQueuing) {
      console.log('Proposal does not need queuing')
      return
    }

    console.log('Queuing proposal...')
    console.log('Targets:', targets)
    console.log('Values:', values)
    console.log('Calldatas:', calldatas)
    console.log('Description:', description)
    console.log('Description Hash:', hashDescription(description))

    // Queue the proposal
    const hash = await walletClient.writeContract({
      address: HUB_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'queue',
      args: [targets, values, calldatas, hashDescription(description)],
      gas: 500000n,
      maxFeePerGas: await publicClient.getGasPrice(),
    })

    console.log('Proposal queued. Transaction hash:', hash)

    // Wait for the transaction to be mined
    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    console.log('Queue transaction mined. Block number:', receipt.blockNumber)
  } catch (error: any) {
    console.error('Error queuing proposal:', error)
    if (error.cause) {
      console.error('Error cause:', error.cause)
      if (error.cause.data) {
        console.error('Error data:', error.cause.data)
      }
    }
  }
}

main().catch(console.error)
