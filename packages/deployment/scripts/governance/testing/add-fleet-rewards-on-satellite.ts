import prompts from 'prompts'
import { Address, encodeFunctionData, Hex, parseAbi } from 'viem'
import { promptForChain, promptForTargetChain } from '../../helpers/chain-prompt'
import { promptForFleet } from '../../helpers/fleet-prompt'
import { hashDescription } from '../../helpers/hash-description'
import { constructLzOptions } from '../../helpers/layerzero-options'
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

  // Get target (satellite) chain configuration
  const {
    config: targetConfig,
    name: targetChainName,
    chain: targetChain,
    rpcUrl: targetRpcUrl,
  } = await promptForTargetChain(hubChainName)

  // Get fleet configuration for the target chain
  const { fleetConfig, rewardsManagerAddress: SATELLITE_REWARDS_MANAGER_ADDRESS } =
    await promptForFleet(targetChainName, targetConfig, targetChain, targetRpcUrl)

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
      validate: (value) => {
        return value > 0 ? true : 'Amount must be greater than 0'
      },
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

  // Extract addresses and IDs from configs
  const HUB_GOVERNOR_ADDRESS = hubConfig.deployedContracts.gov.summerGovernor.address as Address
  const SATELLITE_ENDPOINT_ID = targetConfig.common.layerZero.eID

  // Prepare the satellite chain proposal parameters (target proposal)
  const dstTargets = [rewardToken as Address, SATELLITE_REWARDS_MANAGER_ADDRESS]
  const dstValues = [0n, 0n]
  const dstCalldatas = [
    // First call: approve RewardsManager to spend tokens
    encodeFunctionData({
      abi: parseAbi(['function approve(address spender, uint256 amount)']),
      args: [SATELLITE_REWARDS_MANAGER_ADDRESS, REWARD_AMOUNT_IN_WEI],
    }) as Hex,
    // Second call: notify reward amount
    encodeFunctionData({
      abi: parseAbi([
        'function notifyRewardAmount(address rewardToken, uint256 reward, uint256 newRewardsDuration)',
      ]),
      args: [rewardToken as Address, REWARD_AMOUNT_IN_WEI, BigInt(rewardDuration)],
    }) as Hex,
  ]
  const dstDescription = `Add rewards to ${fleetConfig.fleetName} Fleet (v2)`

  console.log('Destination description:', dstDescription)
  console.log('Hashed destination description:', hashDescription(dstDescription))
  console.log('LayerZero options:', constructLzOptions(200000n))
  console.log('Destination targets:', dstTargets)
  console.log('Destination values:', dstValues)
  console.log('Destination calldatas:', dstCalldatas)

  // Prepare the hub chain proposal parameters (source proposal)
  const srcTargets = [HUB_GOVERNOR_ADDRESS]
  const srcValues = [0n]
  const lzOptions = constructLzOptions(300000n)

  // Encode the cross-chain message parameters
  const srcCalldatas = [
    encodeFunctionData({
      abi: parseAbi([
        'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
      ]),
      args: [
        Number(SATELLITE_ENDPOINT_ID),
        dstTargets,
        dstValues,
        dstCalldatas,
        hashDescription(dstDescription),
        lzOptions,
      ],
    }) as Hex,
  ]

  const srcDescription = `Cross-chain proposal: ${dstDescription}`

  try {
    console.log('Preparing to submit cross-chain proposal...')
    console.log('Source targets:', srcTargets)
    console.log('Source values:', srcValues)
    console.log('Source calldatas:', srcCalldatas)
    console.log('Source description:', srcDescription)
    console.log('Hashed description:', hashDescription(srcDescription))

    // Submit the proposal
    const hash = await walletClient.writeContract({
      address: HUB_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'propose',
      args: [srcTargets, srcValues, srcCalldatas, srcDescription],
      gas: 500000n,
      maxFeePerGas: await publicClient.getGasPrice(),
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
      args: [srcTargets, srcValues, srcCalldatas, hashDescription(srcDescription)],
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
