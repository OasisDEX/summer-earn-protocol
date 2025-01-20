import prompts from 'prompts'
import { Address, parseAbi } from 'viem'
import { promptForChain } from '../../helpers/chain-prompt'
import { createClients } from '../../helpers/wallet-helper'

const governorAbi = parseAbi([
  'function castVote(uint256 proposalId, uint8 support) public returns (uint256)',
  'function state(uint256 proposalId) public view returns (uint8)',
  'function hasVoted(uint256 proposalId, address account) public view returns (bool)',
  'function proposalSnapshot(uint256 proposalId) public view returns (uint256)',
  'function proposalDeadline(uint256 proposalId) public view returns (uint256)',
])

const PROPOSAL_STATES = [
  'Pending',
  'Active',
  'Canceled',
  'Defeated',
  'Succeeded',
  'Queued',
  'Expired',
  'Executed',
]

async function main() {
  const { config, chain, rpcUrl } = await promptForChain('Select the chain:')
  const { publicClient, walletClient } = createClients(chain, rpcUrl)

  // Extract governor address from config
  const SUMMER_GOVERNOR_ADDRESS = config.deployedContracts.gov.summerGovernor.address as Address

  // Prompt for proposal ID
  const { proposalId } = await prompts({
    type: 'text',
    name: 'proposalId',
    message: 'Enter the proposal ID:',
    validate: (value) => {
      try {
        BigInt(value.replace('n', '')) // Remove 'n' suffix if present
        return true
      } catch {
        return 'Please enter a valid proposal ID'
      }
    },
  })

  const cleanProposalId = BigInt(proposalId.toString().replace('n', ''))

  try {
    // Check proposal state
    const state = await publicClient.readContract({
      address: SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'state',
      args: [cleanProposalId],
    })

    console.log(`\nProposal state: ${PROPOSAL_STATES[state]}`)

    if (state !== 1) {
      // 1 is Active state
      throw new Error(`Proposal is not active (current state: ${PROPOSAL_STATES[state]})`)
    }

    // Check if account has already voted
    const hasVoted = await publicClient.readContract({
      address: SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'hasVoted',
      args: [cleanProposalId, walletClient.account!.address],
    })

    if (hasVoted) {
      throw new Error('Account has already voted on this proposal')
    }

    // Get voting period info
    const snapshot = await publicClient.readContract({
      address: SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'proposalSnapshot',
      args: [cleanProposalId],
    })

    const deadline = await publicClient.readContract({
      address: SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'proposalDeadline',
      args: [cleanProposalId],
    })

    const currentBlock = await publicClient.getBlockNumber()

    console.log('\nVoting period:')
    console.log(`Start block: ${snapshot}`)
    console.log(`End block: ${deadline}`)
    console.log(`Current block: ${currentBlock}`)

    // Prompt for vote
    const { support } = await prompts({
      type: 'select',
      name: 'support',
      message: 'How would you like to vote?',
      choices: [
        { title: 'For', value: 1 },
        { title: 'Against', value: 0 },
        { title: 'Abstain', value: 2 },
      ],
    })

    // Confirm the vote
    const { confirmed } = await prompts({
      type: 'confirm',
      name: 'confirmed',
      message: `Are you sure you want to vote ${
        support === 1 ? 'For' : support === 0 ? 'Against' : 'Abstain'
      }?`,
      initial: false,
    })

    if (!confirmed) {
      console.log('Operation cancelled')
      return
    }

    console.log('\nSubmitting vote...')

    // Submit the vote
    const hash = await walletClient.writeContract({
      address: SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'castVote',
      args: [cleanProposalId, support],
    })

    console.log('Vote submitted. Transaction hash:', hash)

    // Wait for the transaction to be mined
    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    console.log('Transaction mined in block:', receipt.blockNumber)
  } catch (error: any) {
    console.error('Error:', error.message)
    if (error.cause) {
      console.error('Error cause:', error.cause)
      if (error.cause.data) {
        console.error('Error data:', error.cause.data)
      }
    }
  }
}

main().catch(console.error)
