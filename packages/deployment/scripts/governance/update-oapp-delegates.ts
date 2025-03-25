import hre from 'hardhat'
import kleur from 'kleur'
import path from 'node:path'
import prompts from 'prompts'
import { Address, encodeFunctionData, Hex } from 'viem'
import { BaseConfig } from '../../types/config-types'
import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { getChainIdByNetwork } from '../helpers/get-chainid'
import { hashDescription } from '../helpers/hash-description'
import { constructLzOptions } from '../helpers/layerzero-options'
import { promptForConfigType } from '../helpers/prompt-helpers'
import { createGovernanceProposal } from '../helpers/proposal-helpers'

// Target chains for the multi-chain proposal
const TARGET_CHAINS = ['base', 'arbitrum', 'mainnet']

/**
 * Creates a multi-chain governance proposal to update SummerToken's OApp delegate to the timelock controller.
 */
async function updateOAppDelegates() {
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

  // Ask about using bummer config
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

  // Display chains being targeted based on bummer config
  const effectiveTargetChains = useBummerConfig
    ? TARGET_CHAINS.filter((chain) => chain !== 'mainnet')
    : TARGET_CHAINS

  // Confirm network selection
  const confirmNetworks = await prompts({
    type: 'confirm',
    name: 'continue',
    message: `This will create a multi-chain governance proposal to update SummerToken's OApp delegate on: ${effectiveTargetChains.join(
      ', ',
    )}. Continue?`,
    initial: true,
  })

  if (!confirmNetworks.continue) {
    console.log(kleur.red('Operation cancelled by user.'))
    return
  }

  // Get SummerToken addresses from config files
  const summerTokenAddresses: Record<string, Address> = {}
  console.log(kleur.cyan('Using SummerToken addresses from config:'))

  // For hub chain
  summerTokenAddresses[HUB_CHAIN_NAME] = hubConfig.deployedContracts.core.summerToken
    .address as Address
  console.log(kleur.yellow(`  ${HUB_CHAIN_NAME}: ${summerTokenAddresses[HUB_CHAIN_NAME]}`))

  // For satellite chains
  for (const chain of TARGET_CHAINS.filter(filterTargetChains)) {
    summerTokenAddresses[chain] = satelliteConfigs[chain].deployedContracts.core.summerToken
      .address as Address
    console.log(kleur.yellow(`  ${chain}: ${summerTokenAddresses[chain]}`))
  }

  // Get Timelock Controller addresses from config files
  const timelockControllerAddresses: Record<string, Address> = {}
  console.log(kleur.cyan('Using Timelock Controller addresses from config:'))

  // For hub chain
  timelockControllerAddresses[HUB_CHAIN_NAME] = hubConfig.deployedContracts.gov.timelock
    .address as Address
  console.log(kleur.yellow(`  ${HUB_CHAIN_NAME}: ${timelockControllerAddresses[HUB_CHAIN_NAME]}`))

  // For satellite chains
  for (const chain of TARGET_CHAINS.filter(filterTargetChains)) {
    timelockControllerAddresses[chain] = satelliteConfigs[chain].deployedContracts.gov.timelock
      .address as Address
    console.log(kleur.yellow(`  ${chain}: ${timelockControllerAddresses[chain]}`))
  }

  // Display summary and ask for confirmation
  if (await confirmProposal(summerTokenAddresses, timelockControllerAddresses)) {
    // Create and save the multi-chain governance proposal
    await createMultiChainOAppDelegateProposal(
      summerTokenAddresses,
      timelockControllerAddresses,
      hubConfig,
      satelliteConfigs,
      useBummerConfig,
    )
  } else {
    console.log(kleur.red().bold('Operation cancelled by user.'))
  }
}

/**
 * Creates a multi-chain governance proposal for updating SummerToken's OApp delegate.
 * @param {Record<string, Address>} summerTokenAddresses - The SummerToken addresses for each chain.
 * @param {Record<string, Address>} timelockControllerAddresses - The Timelock Controller addresses for each chain.
 * @param {BaseConfig} hubConfig - The configuration for the hub chain.
 * @param {Record<string, BaseConfig>} satelliteConfigs - The configurations for the satellite chains.
 * @param {boolean} useBummerConfig - Whether to use bummer config.
 */
async function createMultiChainOAppDelegateProposal(
  summerTokenAddresses: Record<string, Address>,
  timelockControllerAddresses: Record<string, Address>,
  hubConfig: BaseConfig,
  satelliteConfigs: Record<string, BaseConfig>,
  useBummerConfig: boolean,
): Promise<void> {
  console.log(kleur.cyan().bold('\nCreating multi-chain governance proposal...'))

  // Helper function to filter chains based on bummer config
  const filterTargetChains = (chainName: string) => {
    if (chainName === HUB_CHAIN_NAME) return false
    if (useBummerConfig && chainName === 'mainnet') return false
    return true
  }

  try {
    // Get the hub chain governor address
    const hubGovernorAddress = hubConfig.deployedContracts.gov.summerGovernor.address as Address

    // Prepare actions for the hub chain (Base)
    const srcTargets: Address[] = []
    const srcValues: bigint[] = []
    const srcCalldatas: Hex[] = []

    // 1. Prepare hub chain actions (Base)
    console.log(kleur.yellow('Preparing hub chain actions for Base...'))

    // Action to update OApp delegate on hub chain
    srcTargets.push(summerTokenAddresses[HUB_CHAIN_NAME])
    srcValues.push(0n)
    srcCalldatas.push(
      encodeFunctionData({
        abi: [
          {
            name: 'setOAppDelegate',
            type: 'function',
            inputs: [{ name: 'delegate', type: 'address' }],
            outputs: [],
            stateMutability: 'nonpayable',
          },
        ],
        functionName: 'setOAppDelegate',
        args: [timelockControllerAddresses[HUB_CHAIN_NAME]],
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
    for (const chainName of TARGET_CHAINS.filter(filterTargetChains)) {
      const satelliteConfig = satelliteConfigs[chainName]
      const summerTokenAddress = summerTokenAddresses[chainName]
      const timelockAddress = timelockControllerAddresses[chainName]
      const currentChainEndpointId = satelliteConfig.common.layerZero.eID
      const chainId = getChainIdByNetwork(chainName)

      // Prepare the destination chain actions
      const dstTargets: Address[] = []
      const dstValues: bigint[] = []
      const dstCalldatas: Hex[] = []

      // Action to update OApp delegate on satellite chain
      dstTargets.push(summerTokenAddress)
      dstValues.push(0n)
      dstCalldatas.push(
        encodeFunctionData({
          abi: [
            {
              name: 'setOAppDelegate',
              type: 'function',
              inputs: [{ name: 'delegate', type: 'address' }],
              outputs: [],
              stateMutability: 'nonpayable',
            },
          ],
          functionName: 'setOAppDelegate',
          args: [timelockAddress],
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
# SummerToken OApp Delegate Update on ${chainName}

## Summary
This cross-chain proposal updates the SummerToken's OApp delegate on ${chainName} to the Timelock Controller.

## Actions
1. Set SummerToken (${summerTokenAddress}) OApp delegate to Timelock Controller (${timelockAddress})
      `.trim()

      // Add cross-chain proposal action to the source chain actions
      const ESTIMATED_GAS = 300000n
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

      console.log(kleur.green(`- Added cross-chain proposal for ${chainName}`))
    }

    // Get the effective target chains based on bummer config
    const effectiveTargetChains = useBummerConfig
      ? TARGET_CHAINS.filter((chain) => chain !== 'mainnet')
      : TARGET_CHAINS

    // Create title and description for the full proposal
    const title = `SIP6: Multi-Chain SummerToken OApp Delegate Update`
    const description = `
# SIP6: Multi-Chain SummerToken OApp Delegate Update

## Summary
This proposal updates the SummerToken's OApp delegate to be the Timelock Controller across all active chains in the Lazy Summer Protocol ecosystem.

## Motivation
The OApp delegate controls the OApp functionality of the SummerToken, including cross-chain transfers and messaging. Setting the delegate to the Timelock Controller ensures that any changes to the OApp configuration must go through governance, providing additional security and decentralization for the protocol.

## Specifications

### Actions
1. On ${HUB_CHAIN_NAME}: 
   - Set SummerToken OApp delegate to Timelock Controller (${timelockControllerAddresses[HUB_CHAIN_NAME]})
${TARGET_CHAINS.filter(filterTargetChains)
  .map(
    (chain) => `2. Send cross-chain proposal to ${chain} to:
   - Set SummerToken OApp delegate to Timelock Controller (${timelockControllerAddresses[chain]})`,
  )
  .join('\n')}

### Contract Details
${effectiveTargetChains.map((chain) => `- ${chain} SummerToken: ${summerTokenAddresses[chain]}`).join('\n')}
${effectiveTargetChains.map((chain) => `- ${chain} Timelock Controller: ${timelockControllerAddresses[chain]}`).join('\n')}
`.trim()

    // Create action summary for better display
    const actionSummary = [
      `Update SummerToken OApp delegate on ${HUB_CHAIN_NAME}`,
      ...TARGET_CHAINS.filter(filterTargetChains).map(
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
      `${useBummerConfig ? 'test_oapp_delegate' : 'oapp_delegate'}_proposal_${timestamp}.json`,
    )

    console.log(kleur.cyan('Creating governance proposal with the following actions:'))
    console.log(kleur.yellow(`- Update SummerToken OApp delegate on ${HUB_CHAIN_NAME}`))
    for (const chain of TARGET_CHAINS.filter(filterTargetChains)) {
      console.log(kleur.yellow(`- Send cross-chain proposal to ${chain}`))
    }

    // Use createGovernanceProposal directly to save the proposal to JSON
    await createGovernanceProposal(
      title,
      description,
      actions,
      hubGovernorAddress,
      HUB_CHAIN_ID,
      '', // No discourse URL
      actionSummary,
      savePath,
      crossChainExecutions, // Add the cross-chain execution data
    )

    console.log(
      kleur.green('✅ Successfully created multi-chain OApp delegate governance proposal'),
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

/**
 * Displays a summary of the proposal and asks for user confirmation.
 * @param {Record<string, Address>} summerTokenAddresses - The SummerToken addresses for each chain.
 * @param {Record<string, Address>} timelockControllerAddresses - The Timelock Controller addresses for each chain.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmProposal(
  summerTokenAddresses: Record<string, Address>,
  timelockControllerAddresses: Record<string, Address>,
): Promise<boolean> {
  console.log(kleur.cyan().bold('\nSummary of SummerToken OApp Delegate Governance Proposal:'))
  console.log(kleur.yellow('This will create a multi-chain proposal with the following details:'))

  // Display SummerToken addresses
  console.log(kleur.yellow('SummerToken Addresses:'))
  for (const chain of Object.keys(summerTokenAddresses)) {
    console.log(kleur.yellow(`  ${chain}: ${summerTokenAddresses[chain]}`))
  }

  // Display Timelock Controller addresses
  console.log(kleur.yellow('Timelock Controller Addresses:'))
  for (const chain of Object.keys(timelockControllerAddresses)) {
    console.log(kleur.yellow(`  ${chain}: ${timelockControllerAddresses[chain]}`))
  }

  // Ask for confirmation
  const response = await prompts({
    type: 'confirm',
    name: 'continue',
    message: 'Do you want to proceed with creating this multi-chain governance proposal?',
    initial: true,
  })

  return response.continue
}

// Execute the script
updateOAppDelegates().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})

export { updateOAppDelegates }
