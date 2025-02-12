import prompts from 'prompts'
import { Address, encodeFunctionData, parseAbi } from 'viem'
import { promptForChain } from '../../helpers/chain-prompt'
import { promptForFleet } from '../../helpers/fleet-prompt'
import { hashDescription } from '../../helpers/hash-description'
import { createClients } from '../../helpers/wallet-helper'

const governorAbi = parseAbi([
  'function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) public returns (uint256)',
  'function hashProposal(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) public pure returns (uint256)',
])

async function main() {
  // Get hub chain configuration through prompt
  const {
    config: hubConfig,
    chain,
    rpcUrl,
    name: hubChainName,
  } = await promptForChain('Select the hub chain:')

  const { publicClient, walletClient } = createClients(chain, rpcUrl)

  // Get fleet configuration for the hub chain
  const { fleetConfig, rewardsManagerAddress: HUB_REWARDS_MANAGER_ADDRESS } = await promptForFleet(
    hubChainName,
    hubConfig,
    chain,
    rpcUrl,
  )

  // Prompt for reward parameters
  const { rewardToken, rewardAmount, rewardDuration } = await prompts([
    {
      type: 'text',
      name: 'rewardToken',
      message: 'Enter the reward token address:',
      validate: (value) =>
        /^0x[a-fA-F0-9]{40}$/.test(value) ? true : 'Please enter a valid address',
    },
    {
      type: 'number',
      name: 'rewardAmount',
      message:
        'Enter the reward amount (in whole tokens - currently assumes 18 decimals for the reward token):',
      validate: (value) => (value > 0 ? true : 'Amount must be greater than 0'),
    },
    {
      type: 'number',
      name: 'rewardDuration',
      message: 'Enter the reward duration (in seconds):',
      initial: 604800, // 1 week in seconds
      validate: (value) => (value > 0 ? true : 'Duration must be greater than 0'),
    },
  ])

  const REWARD_AMOUNT_IN_WEI = BigInt(rewardAmount) * BigInt(10 ** 18)
  const HUB_GOVERNOR_ADDRESS = hubConfig.deployedContracts.gov.summerGovernor.address as Address

  // Prepare the proposal parameters
  const targets = [rewardToken as Address, HUB_REWARDS_MANAGER_ADDRESS]
  const values = [0n, 0n]
  const calldatas = [
    // First call: approve RewardsManager to spend tokens
    encodeFunctionData({
      abi: parseAbi(['function approve(address spender, uint256 amount)']),
      args: [HUB_REWARDS_MANAGER_ADDRESS, REWARD_AMOUNT_IN_WEI],
    }),
    // Second call: notify reward amount
    encodeFunctionData({
      abi: parseAbi([
        'function notifyRewardAmount(address rewardToken, uint256 reward, uint256 newRewardsDuration)',
      ]),
      args: [rewardToken as Address, REWARD_AMOUNT_IN_WEI, BigInt(rewardDuration)],
    }),
  ]
  const description = `Add rewards to ${fleetConfig.fleetName} Fleet (v2)`

  try {
    console.log('Preparing to submit proposal...')
    console.log('Targets:', targets)
    console.log('Values:', values)
    console.log('Calldatas:', calldatas)
    console.log('Description:', description)
    console.log('Hashed description:', hashDescription(description))

    // Get current block's base fee and add priority fee
    const block = await publicClient.getBlock()
    const maxPriorityFeePerGas = 2_000_000_000n // 2 Gwei
    const maxFeePerGas = block.baseFeePerGas! * 2n + maxPriorityFeePerGas

    // Submit the proposal with proper gas settings
    const hash = await walletClient.writeContract({
      address: HUB_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'propose',
      args: [targets, values, calldatas, description],
      maxFeePerGas,
      maxPriorityFeePerGas,
    })

    console.log('Proposal submitted. Transaction hash:', hash)

    // Wait for the transaction to be mined
    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    console.log('Proposal transaction mined. Block number:', receipt.blockNumber)

    // Get the proposal ID
    const proposalId = await publicClient.readContract({
      address: HUB_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'hashProposal',
      args: [targets, values, calldatas, hashDescription(description)],
    })

    console.log('Proposal ID:', proposalId)
  } catch (error: any) {
    console.error('Error submitting proposal:', error)
    if (error.cause) {
      console.error('Error cause:', error.cause)
      if (error.cause.data) {
        console.error('Error data:', error.cause.data)
      }
    }
  }
}

main().catch(console.error)
