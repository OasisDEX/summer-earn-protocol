import fs from 'fs'
import kleur from 'kleur'
import path from 'path'
import { Address, encodeFunctionData, Hex, parseAbi } from 'viem'
import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../common/constants'
import { promptForChain } from '../helpers/chain-prompt'
import { getChainIdByNetwork } from '../helpers/get-chainid'
import { getSipMinorNumber } from '../helpers/get-sip-minor-number'
import { hashDescription } from '../helpers/hash-description'
import { constructLzOptions } from '../helpers/layerzero-options'
import { createGovernanceProposal } from '../helpers/proposal-helpers'
import { createClients } from '../helpers/wallet-helper'

const governorAbi = parseAbi([
  'function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) public returns (uint256)',
  'function hashProposal(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) public pure returns (uint256)',
])

interface FleetReward {
  address: string
  rewardAddress: string
  fleetCommanderAddress: string
  amount: string
  rewardsDuration: string
  description: string
}

interface ChainFleetRewards {
  fleetRewards: FleetReward[]
}

interface FleetRewardsConfig {
  [chainKey: string]: ChainFleetRewards
}

// Target chains for the multi-chain proposal
const TARGET_CHAINS = ['base', 'arbitrum', 'mainnet', 'sonic']

async function main() {
  // Load fleet rewards configuration
  const fleetRewardsConfigPath = path.join(__dirname, '../launch-config/fleet-rewards.json')
  const fleetRewardsConfig = JSON.parse(
    fs.readFileSync(fleetRewardsConfigPath, 'utf-8'),
  ) as FleetRewardsConfig

  // Get hub chain configuration through prompt
  const {
    config: hubConfig,
    chain,
    rpcUrl,
    name: hubChainName,
  } = await promptForChain('Select the hub chain:')

  const { publicClient, walletClient } = createClients(chain, rpcUrl)

  // Get the governor address
  const HUB_GOVERNOR_ADDRESS = hubConfig.deployedContracts.govV2.summerGovernor.address as Address

  // Get SIP minor number
  const sipMinorNumber = await getSipMinorNumber()

  try {
    // Prepare actions for the hub chain
    const srcTargets: Address[] = []
    const srcValues: bigint[] = []
    const srcCalldatas: Hex[] = []

    // Store cross-chain execution details for the proposal data
    const crossChainExecutions: Array<{
      name: string
      chainId: number
      targets: string[]
      values: string[]
      datas: string[]
    }> = []

    // Process hub chain rewards first
    console.log(kleur.yellow('Preparing hub chain actions...'))
    if (fleetRewardsConfig[HUB_CHAIN_NAME]?.fleetRewards) {
      for (const rewardManager of fleetRewardsConfig[HUB_CHAIN_NAME].fleetRewards) {
        // Add approve call first
        srcTargets.push(rewardManager.rewardAddress as Address)
        srcValues.push(0n)
        srcCalldatas.push(
          encodeFunctionData({
            abi: parseAbi([
              'function approve(address spender, uint256 amount) external returns (bool)',
            ]),
            args: [rewardManager.address as Address, BigInt(rewardManager.amount)],
          }),
        )

        // Add setRewardsDuration call
        srcTargets.push(rewardManager.address as Address)
        srcValues.push(0n)
        srcCalldatas.push(
          encodeFunctionData({
            abi: parseAbi([
              'function setRewardsDuration(address rewardToken, uint256 _rewardsDuration) external',
            ]),
            args: [rewardManager.rewardAddress as Address, BigInt(rewardManager.rewardsDuration)],
          }),
        )

        // Add notifyRewardAmount call
        srcTargets.push(rewardManager.address as Address)
        srcValues.push(0n)
        srcCalldatas.push(
          encodeFunctionData({
            abi: parseAbi([
              'function notifyRewardAmount(address rewardToken, uint256 reward, uint256 newRewardsDuration) external',
            ]),
            args: [
              rewardManager.rewardAddress as Address,
              BigInt(rewardManager.amount),
              BigInt(rewardManager.rewardsDuration),
            ],
          }),
        )
      }
    }

    // Process satellite chain rewards
    console.log(kleur.yellow('Preparing cross-chain actions for satellite chains...'))
    for (const chainName of TARGET_CHAINS.filter((chain) => chain !== HUB_CHAIN_NAME)) {
      if (!fleetRewardsConfig[chainName]?.fleetRewards) continue

      const chainConfig = await promptForChain(`Select the ${chainName} chain configuration:`)
      const currentChainEndpointId = chainConfig.config.common.layerZero.eID
      const chainId = getChainIdByNetwork(chainName)

      // Prepare the destination chain actions
      const dstTargets: Address[] = []
      const dstValues: bigint[] = []
      const dstCalldatas: Hex[] = []

      for (const rewardManager of fleetRewardsConfig[chainName].fleetRewards) {
        // Add approve call first
        dstTargets.push(rewardManager.rewardAddress as Address)
        dstValues.push(0n)
        dstCalldatas.push(
          encodeFunctionData({
            abi: parseAbi([
              'function approve(address spender, uint256 amount) external returns (bool)',
            ]),
            args: [rewardManager.address as Address, BigInt(rewardManager.amount)],
          }),
        )

        // Add setRewardsDuration call
        dstTargets.push(rewardManager.address as Address)
        dstValues.push(0n)
        dstCalldatas.push(
          encodeFunctionData({
            abi: parseAbi([
              'function setRewardsDuration(address rewardToken, uint256 _rewardsDuration) external',
            ]),
            args: [rewardManager.rewardAddress as Address, BigInt(rewardManager.rewardsDuration)],
          }),
        )

        // Add notifyRewardAmount call
        dstTargets.push(rewardManager.address as Address)
        dstValues.push(0n)
        dstCalldatas.push(
          encodeFunctionData({
            abi: parseAbi([
              'function notifyRewardAmount(address rewardToken, uint256 reward, uint256 newRewardsDuration) external',
            ]),
            args: [
              rewardManager.rewardAddress as Address,
              BigInt(rewardManager.amount),
              BigInt(rewardManager.rewardsDuration),
            ],
          }),
        )
      }

      // Store cross-chain execution data for this chain
      crossChainExecutions.push({
        name: chainName,
        chainId: Number(chainId),
        targets: dstTargets.map((t) => t as string),
        values: dstValues.map((v) => v.toString()),
        datas: dstCalldatas.map((c) => c as string),
      })

      // Create destination chain description
      const dstDescription = `
# Fleet Rewards Setup on ${chainName}

## Summary
This cross-chain proposal sets up rewards for fleets on ${chainName} by updating reward durations and notifying reward amounts.

## Actions
${fleetRewardsConfig[chainName].fleetRewards
  .map(
    (reward) => `
    1. Approve ${reward.amount} ${reward.rewardAddress} tokens for ${reward.address}
    2. Change reward duration for ${reward.description} to ${reward.rewardsDuration} seconds
    3. Notify reward amount of ${reward.amount} tokens for ${reward.description}`,
  )
  .join('\n')}
      `.trim()

      // Add cross-chain proposal action to the source chain actions
      const ESTIMATED_GAS = 400000n
      const lzOptions = constructLzOptions(ESTIMATED_GAS)

      srcTargets.push(HUB_GOVERNOR_ADDRESS)
      srcValues.push(0n)
      srcCalldatas.push(
        encodeFunctionData({
          abi: parseAbi([
            'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
          ]),
          functionName: 'sendProposalToTargetChain',
          args: [
            Number(currentChainEndpointId),
            dstTargets,
            dstValues,
            dstCalldatas,
            hashDescription(dstDescription),
            lzOptions,
          ],
        }),
      )

      console.log(kleur.green(`- Added cross-chain proposal for ${chainName}`))
    }

    // Create title and description for the full proposal
    const sipNumber = sipMinorNumber !== undefined ? `SIP5.${sipMinorNumber}` : 'SIP5'
    const title = `${sipNumber}: Multi-Chain Fleet Rewards Setup`
    const description = `
# ${sipNumber}: Multi-Chain Fleet Rewards Setup

## Summary
This proposal sets up rewards for fleets across all active chains in the Lazy Summer Protocol ecosystem by updating reward durations and notifying reward amounts.

## Motivation
Fleet rewards need to be properly configured to ensure continuous operation of the protocol. This includes setting appropriate reward durations and notifying reward amounts for each fleet.

## Specifications

### Actions
${HUB_CHAIN_NAME}:
${
  fleetRewardsConfig[HUB_CHAIN_NAME]?.fleetRewards
    .map(
      (reward) => `
- Change reward duration for ${reward.description} to ${reward.rewardsDuration} seconds
- Notify reward amount of ${reward.amount} tokens for ${reward.description}`,
    )
    .join('\n') || 'No rewards configured'
}

${TARGET_CHAINS.filter((chain) => chain !== HUB_CHAIN_NAME)
  .map(
    (chain) => `
${chain}:
${
  fleetRewardsConfig[chain]?.fleetRewards
    .map(
      (reward) => `
- Change reward duration for ${reward.description} to ${reward.rewardsDuration} seconds
- Notify reward amount of ${reward.amount} tokens for ${reward.description}`,
    )
    .join('\n') || 'No rewards configured'
}`,
  )
  .join('\n')}

## Technical Details
The proposal updates reward durations and notifies reward amounts for each fleet across all chains. This ensures proper reward distribution and timing for all protocol participants.
`.trim()

    // Create action summary for better display
    const actionSummary = [
      `Update rewards on ${HUB_CHAIN_NAME}`,
      ...TARGET_CHAINS.filter((chain) => chain !== HUB_CHAIN_NAME).map(
        (chain) => `Send cross-chain proposal to ${chain}`,
      ),
    ]

    // Convert targets, values, and calldatas into ProposalAction array
    const actions = srcTargets.map((target, index) => ({
      target,
      value: srcValues[index],
      calldata: srcCalldatas[index],
    }))

    // Generate a save path for the proposal JSON
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    const savePath = path.join(
      process.cwd(),
      '/proposals',
      `fleet_rewards_proposal_${timestamp}.json`,
    )

    console.log(kleur.cyan('Creating governance proposal with the following actions:'))
    console.log(kleur.yellow(`- Update rewards on ${HUB_CHAIN_NAME}`))
    for (const chain of TARGET_CHAINS.filter((chain) => chain !== HUB_CHAIN_NAME)) {
      console.log(kleur.yellow(`- Send cross-chain proposal to ${chain}`))
    }

    // Use createGovernanceProposal to save the proposal to JSON
    await createGovernanceProposal(
      title,
      description,
      actions,
      HUB_GOVERNOR_ADDRESS,
      HUB_CHAIN_ID,
      '', // No discourse URL
      actionSummary,
      savePath,
      crossChainExecutions,
    )

    console.log(
      kleur.green('✅ Successfully created multi-chain fleet rewards governance proposal'),
    )
    console.log(
      kleur.yellow(
        'The proposal has been saved to a JSON file in the proposals directory and can be submitted manually.',
      ),
    )
  } catch (error) {
    console.error(kleur.red('Error creating multi-chain governance proposal:'), error)
    throw error
  }
}

main().catch(console.error)
