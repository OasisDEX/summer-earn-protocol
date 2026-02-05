import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address, encodeFunctionData, Hex } from 'viem'
import { BaseConfig } from '../../types/config-types'
import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../common/constants'
import { getChainPublicClient } from '../helpers/client-by-chain-helper'
import { getConfigByNetwork } from '../helpers/config-handler'
import { getChainIdByNetwork } from '../helpers/get-chainid'
import { getSipMinorNumber } from '../helpers/get-sip-minor-number'
import { hashDescription } from '../helpers/hash-description'
import { constructLzOptions } from '../helpers/layerzero-options'
import { promptForConfigType } from '../helpers/prompt-helpers'
import { createGovernanceProposal } from '../helpers/proposal-helpers'

// Target chains for the multi-chain proposal
const TARGET_CHAINS = ['base', 'arbitrum', 'mainnet', 'sonic']

/**
 * Creates a multi-chain governance proposal to update governance parameters.
 * - Updates votingDelay and votingPeriod on the Hub chain (Base) only
 * - Updates execution delay (minDelay) on both Hub chain and satellite chains
 */
async function updateGovernanceParams() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  // Verify we're on the hub chain
  if (network !== HUB_CHAIN_NAME) {
    console.log(
      kleur.red(
        `This script must be run on ${HUB_CHAIN_NAME} to create the multi-chain governance proposal.`,
      ),
    )
    return
  }

  // Ask about using bummer config (test configuration)
  const useBummerConfig = await promptForConfigType()

  // Helper function to filter chains based on bummer config
  const filterTargetChains = (chainName: string) => {
    if (chainName === HUB_CHAIN_NAME) return false
    if (useBummerConfig && chainName === 'mainnet') return false
    return true
  }

  // Load the configuration for the hub chain (Base)
  const hubConfig = getConfigByNetwork(
    HUB_CHAIN_NAME,
    { common: true, core: true, gov: true },
    useBummerConfig,
  )

  // Load configurations for satellite chains
  const satelliteConfigs: Record<string, BaseConfig> = {}
  for (const chain of TARGET_CHAINS.filter(filterTargetChains)) {
    satelliteConfigs[chain] = getConfigByNetwork(
      chain,
      { common: true, core: true, gov: true },
      useBummerConfig,
    )
  }

  // Fetch current governance parameters
  const { currentVotingDelay, currentVotingPeriod, currentTimelockDelay } =
    await fetchCurrentGovernanceParams(hubConfig)

  // Fetch timelock delays from all chains
  console.log(kleur.cyan('\nFetching current timelock delays from satellite chains...'))
  const currentTimelockDelays = await fetchAllTimelockDelays(
    hubConfig,
    satelliteConfigs,
    filterTargetChains,
  )

  // Display chains being targeted based on bummer config
  const effectiveTargetChains = TARGET_CHAINS.filter(filterTargetChains)

  // First show current values
  console.log(kleur.cyan('Reading current governance parameters from contracts...'))
  console.log(kleur.yellow(`Hub Chain (${HUB_CHAIN_NAME}):`))
  console.log(
    kleur.yellow(
      `- Voting Delay: ${currentVotingDelay} seconds (${currentVotingDelay / 86400} days)`,
    ),
  )
  console.log(
    kleur.yellow(
      `- Voting Period: ${currentVotingPeriod} seconds (${currentVotingPeriod / 86400} days)`,
    ),
  )
  console.log(
    kleur.yellow(
      `- Timelock Delay (Execution): ${currentTimelockDelay} seconds (${currentTimelockDelay / 86400} days)`,
    ),
  )

  console.log(kleur.yellow(`\nSatellite Chains (${effectiveTargetChains.join(', ')}):`))
  console.log(
    kleur.yellow(
      `- Timelock Delay (Execution): ${currentTimelockDelay} seconds (${currentTimelockDelay / 86400} days)`,
    ),
  )

  // Then clearly indicate we're starting proposal creation
  console.log(kleur.cyan('\nPreparing to create a governance parameter update proposal'))

  // Ask if user wants to continue
  const confirmProceed = await prompts({
    type: 'confirm',
    name: 'continue',
    message: `Do you want to create a proposal to update these parameters?`,
    initial: true,
  })

  if (!confirmProceed.continue) {
    console.log(kleur.red('Operation cancelled by user.'))
    return
  }

  // Then ask for new values
  console.log(kleur.cyan('\nEnter new governance parameters:'))
  const { votingDelay, votingPeriod, timelockDelay, discourseURL } = await prompts([
    {
      type: 'number',
      name: 'votingDelay',
      message: 'Enter the new voting delay for Hub chain (in seconds):',
      initial: currentVotingDelay, // Use current value as default
      validate: (value) => (value > 0 ? true : 'Voting delay must be positive'),
    },
    {
      type: 'number',
      name: 'votingPeriod',
      message: 'Enter the new voting period for Hub chain (in seconds):',
      initial: currentVotingPeriod, // Use current value as default
      validate: (value) => (value > 0 ? true : 'Voting period must be positive'),
    },
    {
      type: 'number',
      name: 'timelockDelay',
      message: 'Enter the new timelock delay (execution delay) for all chains (in seconds):',
      initial: currentTimelockDelay,
      validate: (value) => (value >= 0 ? true : 'Timelock delay must be non-negative'),
    },
    {
      type: 'text',
      name: 'discourseURL',
      message: 'Enter the Discourse URL for the proposal discussion (leave empty for none):',
      initial:
        'https://forum.summer.fi/t/rfc-adjust-governance-parameters-reduce-execution-delay-voting-period/206',
    },
  ])

  // Display the governance parameters to be updated
  console.log(kleur.cyan('\nGovernance Parameters to Update:'))
  console.log(kleur.yellow(`Hub Chain (${HUB_CHAIN_NAME}):`))
  console.log(kleur.yellow(`- Voting Delay: ${votingDelay} seconds (${votingDelay / 86400} days)`))
  console.log(
    kleur.yellow(`- Voting Period: ${votingPeriod} seconds (${votingPeriod / 86400} days)`),
  )
  console.log(
    kleur.yellow(
      `- Timelock Delay (Execution): ${timelockDelay} seconds (${timelockDelay / 86400} days)`,
    ),
  )

  console.log(kleur.yellow(`\nSatellite Chains (${effectiveTargetChains.join(', ')}):`))
  console.log(
    kleur.yellow(
      `- Timelock Delay (Execution): ${timelockDelay} seconds (${timelockDelay / 86400} days)`,
    ),
  )

  const confirmParams = await prompts({
    type: 'confirm',
    name: 'continue',
    message: 'Are these parameters correct?',
    initial: true,
  })

  if (!confirmParams.continue) {
    console.log(kleur.red('Operation cancelled by user.'))
    return
  }

  // Prepare the proposal
  await createMultiChainGovernanceParamsProposal(
    {
      votingDelay,
      votingPeriod,
      timelockDelay,
      discourseURL,
      currentTimelockDelays,
    },
    hubConfig,
    satelliteConfigs,
    useBummerConfig,
  )
}

/**
 * Creates a multi-chain governance proposal for updating governance parameters.
 * @param {Object} params - The new governance parameters.
 * @param {BaseConfig} hubConfig - The configuration for the hub chain.
 * @param {Record<string, BaseConfig>} satelliteConfigs - The configurations for the satellite chains.
 * @param {boolean} useBummerConfig - Whether to use bummer config.
 */
async function createMultiChainGovernanceParamsProposal(
  params: {
    votingDelay: number
    votingPeriod: number
    timelockDelay: number
    discourseURL: string
    currentTimelockDelays: Record<string, number>
  },
  hubConfig: BaseConfig,
  satelliteConfigs: Record<string, BaseConfig>,
  useBummerConfig: boolean,
): Promise<void> {
  console.log(kleur.cyan().bold('\nCreating governance parameter proposal...'))

  // Helper function to filter chains based on bummer config
  const filterTargetChains = (chainName: string) => {
    if (chainName === HUB_CHAIN_NAME) return false
    if (useBummerConfig && chainName === 'mainnet') return false
    return true
  }

  // Get SIP minor number
  const sipMinorNumber = await getSipMinorNumber()

  try {
    // Get the hub chain governor and timelock addresses
    const hubGovernorAddress = hubConfig.deployedContracts.govV2.summerGovernor.address as Address
    const hubTimelockAddress = hubConfig.deployedContracts.gov.timelock.address as Address

    // Prepare actions for the hub chain (Base)
    const srcTargets: Address[] = []
    const srcValues: bigint[] = []
    const srcCalldatas: Hex[] = []

    // 1. Update voting delay on hub chain only
    srcTargets.push(hubGovernorAddress)
    srcValues.push(0n)
    srcCalldatas.push(
      encodeFunctionData({
        abi: [
          {
            name: 'setVotingDelay',
            type: 'function',
            inputs: [{ name: 'newVotingDelay', type: 'uint48' }],
            outputs: [],
            stateMutability: 'nonpayable',
          },
        ],
        functionName: 'setVotingDelay',
        args: [params.votingDelay],
      }),
    )

    // 2. Update voting period on hub chain only
    srcTargets.push(hubGovernorAddress)
    srcValues.push(0n)
    srcCalldatas.push(
      encodeFunctionData({
        abi: [
          {
            name: 'setVotingPeriod',
            type: 'function',
            inputs: [{ name: 'newVotingPeriod', type: 'uint32' }],
            outputs: [],
            stateMutability: 'nonpayable',
          },
        ],
        functionName: 'setVotingPeriod',
        args: [params.votingPeriod],
      }),
    )

    // 3. Update execution delay (minDelay) on hub chain
    srcTargets.push(hubTimelockAddress)
    srcValues.push(0n)
    srcCalldatas.push(
      encodeFunctionData({
        abi: [
          {
            name: 'updateDelay',
            type: 'function',
            inputs: [{ name: 'newDelay', type: 'uint256' }],
            outputs: [],
            stateMutability: 'nonpayable',
          },
        ],
        functionName: 'updateDelay',
        args: [BigInt(params.timelockDelay)],
      }),
    )

    // Store cross-chain execution details for the proposal data
    const crossChainExecutions: Array<{
      name: string
      chainId: number
      targets: string[]
      values: string[]
      datas: string[]
    }> = []

    // 2. Prepare cross-chain actions for each satellite chain
    console.log(kleur.yellow('Preparing cross-chain actions for satellite chains...'))

    // Calculate which chains need updates
    const chainsNeedingUpdate = TARGET_CHAINS.filter(filterTargetChains).filter((chainName) => {
      // Skip chains where the timelock delay isn't changing
      const currentDelay = params.currentTimelockDelays[chainName]
      if (currentDelay === undefined) {
        console.log(
          kleur.yellow(`- Including ${chainName} because current delay couldn't be fetched`),
        )
        return true
      }

      const isChanging = currentDelay !== params.timelockDelay

      if (!isChanging) {
        console.log(
          kleur.blue(
            `- Skipping ${chainName} as execution delay is already ${currentDelay} seconds (${currentDelay / 86400} days)`,
          ),
        )
        return false
      }

      console.log(
        kleur.green(
          `- Including ${chainName} to update delay from ${currentDelay} seconds to ${params.timelockDelay} seconds`,
        ),
      )
      return true
    })

    // Only process chains that need updates
    for (const chainName of chainsNeedingUpdate) {
      const satelliteConfig = satelliteConfigs[chainName]
      const timelockAddress = satelliteConfig.deployedContracts.gov.timelock.address as Address
      const currentChainEndpointId = satelliteConfig.common.layerZero.eID
      const chainId = getChainIdByNetwork(chainName)

      // Prepare the destination chain actions
      const dstTargets: Address[] = []
      const dstValues: bigint[] = []
      const dstCalldatas: Hex[] = []

      // For satellite chains, only update execution delay (minDelay)
      dstTargets.push(timelockAddress)
      dstValues.push(0n)
      dstCalldatas.push(
        encodeFunctionData({
          abi: [
            {
              name: 'updateDelay',
              type: 'function',
              inputs: [{ name: 'newDelay', type: 'uint256' }],
              outputs: [],
              stateMutability: 'nonpayable',
            },
          ],
          functionName: 'updateDelay',
          args: [BigInt(params.timelockDelay)],
        }),
      )

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
# Timelock Execution Delay Update on ${chainName}

## Summary
This cross-chain proposal updates the timelock execution delay on ${chainName} to:
- Set Execution Delay: ${params.timelockDelay} seconds (${params.timelockDelay / 86400} days)

## Actions
1. Update execution delay (minDelay) on the TimelockController contract
      `.trim()

      // Add cross-chain proposal action to the source chain actions
      const ESTIMATED_GAS = 400000n
      const lzOptions = constructLzOptions(ESTIMATED_GAS)

      srcTargets.push(hubGovernorAddress)
      srcValues.push(0n)
      srcCalldatas.push(
        encodeFunctionData({
          abi: [
            {
              name: 'sendProposalToTargetChain',
              type: 'function',
              inputs: [
                { name: '_dstEid', type: 'uint32' },
                { name: '_dstTargets', type: 'address[]' },
                { name: '_dstValues', type: 'uint256[]' },
                { name: '_dstCalldatas', type: 'bytes[]' },
                { name: '_dstDescriptionHash', type: 'bytes32' },
                { name: '_options', type: 'bytes' },
              ],
              outputs: [],
              stateMutability: 'nonpayable',
            },
          ],
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

      console.log(
        kleur.green(`- Added cross-chain proposal for ${chainName} (timelock delay update only)`),
      )
    }

    // Get the effective target chains based on bummer config
    const effectiveTargetChains = TARGET_CHAINS.filter(filterTargetChains)

    // Create title and description for the full proposal
    const sipNumber = sipMinorNumber !== undefined ? `SIP4.${sipMinorNumber}` : 'SIP4'
    const title = `${sipNumber}: Adjust Governance Parameters`
    const description = `
# ${sipNumber}: Adjust Governance Parameters

## Summary
This proposal adjusts the governance parameters across all Lazy Summer Protocol chains to optimize the governance process based on community feedback:

- On ${HUB_CHAIN_NAME} (Hub Chain):
  - Voting Delay: ${params.votingDelay} seconds (${params.votingDelay / 86400} days)
  - Voting Period: ${params.votingPeriod} seconds (${params.votingPeriod / 86400} days)
  - Timelock Delay (Execution): ${params.timelockDelay} seconds (${params.timelockDelay / 86400} days)

- On Satellite Chains:
  - Timelock Delay (Execution): ${params.timelockDelay} seconds (${params.timelockDelay / 86400} days)

## Motivation
As discussed in the [governance forum](https://forum.summer.fi/t/rfc-adjust-governance-parameters-reduce-execution-delay-voting-period/206), the current governance parameters have been found to be longer than necessary. These adjustments will streamline the governance process while still maintaining adequate time for community participation and security considerations.

The new governance flow will be:
- Post Tally Vote → Wednesday
- Tally Vote Opens for Voting → Thursday - Friday - Saturday
- Vote Execution Delay → Sunday (Base Network) / Monday (Other Networks)

## Specifications
### Actions on ${HUB_CHAIN_NAME} (Hub Chain):
1. Update voting delay to ${params.votingDelay} seconds
2. Update voting period to ${params.votingPeriod} seconds
3. Update execution delay to ${params.timelockDelay} seconds

${effectiveTargetChains
  .map(
    (chainName) => `### Actions on ${chainName} (via Cross-Chain Proposal):
1. Update execution delay to ${params.timelockDelay} seconds`,
  )
  .join('\n\n')}

## Technical Details
The proposal updates the following parameters:

- **Voting Delay**: The time between a proposal being submitted and voting beginning (setVotingDelay function) - Hub Chain only
- **Voting Period**: The duration of the voting window (setVotingPeriod function) - Hub Chain only
- **Execution Delay**: The timelock period after a proposal passes before it can be executed (updateDelay function) - All chains

Since all governance voting occurs on the hub chain, voting delay and period parameters are only updated there, while the execution delay is updated across all chains to maintain consistent security guarantees.
`.trim()

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
      `${useBummerConfig ? 'test_governance_params' : 'governance_params'}_proposal_${timestamp}.json`,
    )

    console.log(kleur.cyan('Creating governance proposal with the following actions:'))
    console.log(kleur.yellow(`- Update voting parameters and timelock delay on ${HUB_CHAIN_NAME}`))
    for (const chain of TARGET_CHAINS.filter(filterTargetChains)) {
      console.log(kleur.yellow(`- Send cross-chain proposal to update timelock delay on ${chain}`))
    }

    // Use createGovernanceProposal to save the proposal to JSON
    await createGovernanceProposal(
      title,
      description,
      actions,
      hubGovernorAddress,
      HUB_CHAIN_ID,
      params.discourseURL,
      [
        `Update voting delay to ${params.votingDelay / 86400} days (Hub only)`,
        `Update voting period to ${params.votingPeriod / 86400} days (Hub only)`,
        `Update execution delay to ${params.timelockDelay / 86400} days (All chains)`,
        ...effectiveTargetChains.map(
          (chain) => `Send cross-chain proposal to update timelock delay on ${chain}`,
        ),
      ],
      savePath,
      crossChainExecutions,
    )

    console.log(kleur.green('✅ Successfully created governance parameter update proposal'))
    console.log(
      kleur.yellow(
        'The proposal has been saved to a JSON file in the proposals directory and can be submitted via Tally.',
      ),
    )
  } catch (error) {
    console.error(kleur.red('Error creating multi-chain governance proposal:'), error)
    throw error
  }
}

/**
 * Fetches the current governance parameters from the contracts
 */
async function fetchCurrentGovernanceParams(hubConfig: BaseConfig): Promise<{
  currentVotingDelay: number
  currentVotingPeriod: number
  currentTimelockDelay: number
}> {
  const publicClient = await hre.viem.getPublicClient()
  const governorAddress = hubConfig.deployedContracts.govV2.summerGovernor.address as Address
  const timelockAddress = hubConfig.deployedContracts.gov.timelock.address as Address

  try {
    // Read votingDelay from SummerGovernor
    const currentVotingDelay = Number(
      await publicClient.readContract({
        address: governorAddress,
        abi: [
          {
            name: 'votingDelay',
            type: 'function',
            inputs: [],
            outputs: [{ type: 'uint256', name: '' }],
            stateMutability: 'view',
          },
        ],
        functionName: 'votingDelay',
      }),
    )

    // Read votingPeriod from SummerGovernor
    const currentVotingPeriod = Number(
      await publicClient.readContract({
        address: governorAddress,
        abi: [
          {
            name: 'votingPeriod',
            type: 'function',
            inputs: [],
            outputs: [{ type: 'uint256', name: '' }],
            stateMutability: 'view',
          },
        ],
        functionName: 'votingPeriod',
      }),
    )

    // Read minDelay from TimelockController
    const getMinDelayAbi = [
      {
        name: 'getMinDelay',
        type: 'function',
        inputs: [],
        outputs: [{ type: 'uint256', name: '' }],
        stateMutability: 'view',
      },
    ] as const

    const currentTimelockDelay = Number(
      await publicClient.readContract({
        address: timelockAddress,
        abi: getMinDelayAbi,
        functionName: 'getMinDelay',
      }),
    )

    return { currentVotingDelay, currentVotingPeriod, currentTimelockDelay }
  } catch (error) {
    console.error(kleur.red('Error reading current governance parameters:'), error)
    throw error
  }
}

/**
 * Fetches the current timelock delay from a specific chain
 */
async function fetchCurrentTimelockDelay(
  chainName: string,
  timelockAddress: Address,
): Promise<number> {
  try {
    // Get a public client for the specified chain
    const publicClient = await getChainPublicClient(chainName)

    // Read minDelay from TimelockController
    const getMinDelayAbi = [
      {
        name: 'getMinDelay',
        type: 'function',
        inputs: [],
        outputs: [{ type: 'uint256', name: '' }],
        stateMutability: 'view',
      },
    ] as const

    const currentTimelockDelay = Number(
      await publicClient.readContract({
        address: timelockAddress,
        abi: getMinDelayAbi,
        functionName: 'getMinDelay',
      }),
    )

    return currentTimelockDelay
  } catch (error) {
    console.error(kleur.red(`Error reading timelock delay for ${chainName}:`), error)
    throw error
  }
}

/**
 * Fetches timelock delays from all chains
 */
async function fetchAllTimelockDelays(
  hubConfig: BaseConfig,
  satelliteConfigs: Record<string, BaseConfig>,
  filterTargetChains: (chainName: string) => boolean,
): Promise<Record<string, number>> {
  console.log(kleur.cyan('Reading current timelock delays from all chains...'))

  const delays: Record<string, number> = {}

  // Fetch hub chain timelock delay
  try {
    const hubTimelockAddress = hubConfig.deployedContracts.gov.timelock.address as Address
    delays[HUB_CHAIN_NAME] = await fetchCurrentTimelockDelay(HUB_CHAIN_NAME, hubTimelockAddress)
    console.log(
      kleur.yellow(
        `- ${HUB_CHAIN_NAME}: ${delays[HUB_CHAIN_NAME]} seconds (${delays[HUB_CHAIN_NAME] / 86400} days)`,
      ),
    )
  } catch (error) {
    console.error(kleur.red(`Could not fetch timelock delay for ${HUB_CHAIN_NAME}`))
  }

  // Fetch satellite chain timelock delays
  for (const chainName of TARGET_CHAINS.filter(filterTargetChains)) {
    try {
      const timelockAddress = satelliteConfigs[chainName].deployedContracts.gov.timelock
        .address as Address
      delays[chainName] = await fetchCurrentTimelockDelay(chainName, timelockAddress)
      console.log(
        kleur.yellow(
          `- ${chainName}: ${delays[chainName]} seconds (${delays[chainName] / 86400} days)`,
        ),
      )
    } catch (error) {
      console.error(kleur.red(`Could not fetch timelock delay for ${chainName}`))
    }
  }

  return delays
}

// Execute the script if called directly
if (require.main === module) {
  updateGovernanceParams().catch((error) => {
    if (error.message.includes('Tally api mutations not supported yet')) {
      process.exit(0)
    } else {
      console.error(kleur.red().bold('An error occurred:'), error)
    }
    process.exit(1)
  })
}

export { updateGovernanceParams }
