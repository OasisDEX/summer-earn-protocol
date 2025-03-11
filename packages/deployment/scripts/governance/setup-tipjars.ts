import hre from 'hardhat'
import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import prompts from 'prompts'
import { Address, encodeFunctionData, Hex } from 'viem'
import TipJarAbi from '../../artifacts/src/contracts/TipJar.sol/TipJar.json'
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

interface TipStream {
  recipient: Address
  allocation: string
  minTerm: string
}

interface TipStreamsConfig {
  tipStreams: TipStream[]
}

/**
 * Creates a multi-chain governance proposal to update TipJars on Base, Arbitrum, and Mainnet.
 */
async function setupTipJars() {
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
    message: `This will create a multi-chain governance proposal to update TipJars on: ${effectiveTargetChains.join(
      ', ',
    )}. Continue?`,
    initial: true,
  })

  if (!confirmNetworks.continue) {
    console.log(kleur.red('Operation cancelled by user.'))
    return
  }

  // Load tip streams configuration
  const tipStreamsConfig = await loadTipStreamsConfig()

  // Get TipJar addresses from config files
  const tipJarAddresses: Record<string, Address> = {}
  console.log(kleur.cyan('Using TipJar addresses from config:'))

  // For hub chain
  tipJarAddresses[HUB_CHAIN_NAME] = hubConfig.deployedContracts.core.tipJar.address as Address
  console.log(kleur.yellow(`  ${HUB_CHAIN_NAME}: ${tipJarAddresses[HUB_CHAIN_NAME]}`))

  // For satellite chains
  for (const chain of TARGET_CHAINS.filter(filterTargetChains)) {
    tipJarAddresses[chain] = satelliteConfigs[chain].deployedContracts.core.tipJar
      .address as Address
    console.log(kleur.yellow(`  ${chain}: ${tipJarAddresses[chain]}`))
  }

  // Display summary and ask for confirmation
  if (await confirmProposal(tipJarAddresses, tipStreamsConfig)) {
    // Create and save the multi-chain governance proposal
    await createMultiChainTipJarProposal(
      tipJarAddresses,
      hubConfig,
      satelliteConfigs,
      tipStreamsConfig,
      useBummerConfig,
    )
  } else {
    console.log(kleur.red().bold('Operation cancelled by user.'))
  }
}

/**
 * Loads the tip streams configuration from the JSON file.
 * @returns {Promise<TipStreamsConfig>} The tip streams configuration.
 */
async function loadTipStreamsConfig(): Promise<TipStreamsConfig> {
  try {
    const configPath = path.resolve(__dirname, '../launch-config/tip-streams.json')

    // Check if file exists, if not create with empty config
    if (!fs.existsSync(configPath)) {
      console.log(kleur.yellow('Tip streams configuration file not found. Creating empty config.'))
      const emptyConfig = { tipStreams: [] }
      fs.writeFileSync(configPath, JSON.stringify(emptyConfig, null, 2))
      return emptyConfig
    }

    const tipStreamsConfig: TipStreamsConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'))

    if (!tipStreamsConfig.tipStreams || tipStreamsConfig.tipStreams.length === 0) {
      console.log(kleur.yellow('Warning: No tip streams configured in tip-streams.json.'))
    } else {
      console.log(
        kleur.green(`Loaded ${tipStreamsConfig.tipStreams.length} tip streams from config.`),
      )
    }

    return tipStreamsConfig
  } catch (error) {
    console.error(kleur.red('Error loading tip streams configuration:'), error)
    // Return empty config on error
    return { tipStreams: [] }
  }
}

/**
 * Creates a multi-chain governance proposal for updating TipJars.
 * @param {Record<string, Address>} tipJarAddresses - The TipJar addresses for each chain.
 * @param {BaseConfig} hubConfig - The configuration for the hub chain.
 * @param {Record<string, BaseConfig>} satelliteConfigs - The configurations for the satellite chains.
 * @param {TipStreamsConfig} tipStreamsConfig - The tip streams configuration.
 * @param {boolean} useBummerConfig - Whether to use bummer config.
 */
async function createMultiChainTipJarProposal(
  tipJarAddresses: Record<string, Address>,
  hubConfig: BaseConfig,
  satelliteConfigs: Record<string, BaseConfig>,
  tipStreamsConfig: TipStreamsConfig,
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
    const baseConfigManagerAddress = hubConfig.deployedContracts.core.configurationManager
      .address as Address

    // Action to update ConfigurationManager on Base
    srcTargets.push(baseConfigManagerAddress)
    srcValues.push(0n)
    srcCalldatas.push(
      encodeFunctionData({
        abi: [
          {
            name: 'setTipJar',
            type: 'function',
            inputs: [{ name: 'newTipJar', type: 'address' }],
            outputs: [],
            stateMutability: 'nonpayable',
          },
        ],
        functionName: 'setTipJar',
        args: [tipJarAddresses[HUB_CHAIN_NAME]],
      }),
    )

    // Add actions to set up tip streams on Base
    if (tipStreamsConfig.tipStreams && tipStreamsConfig.tipStreams.length > 0) {
      for (const stream of tipStreamsConfig.tipStreams) {
        console.log('Processing stream:', stream)
        srcTargets.push(tipJarAddresses[HUB_CHAIN_NAME])
        srcValues.push(0n)

        // Use the actual contract ABI
        const addTipStreamAbi = TipJarAbi.abi.find(
          (item) => item.type === 'function' && item.name === 'addTipStream',
        )

        if (!addTipStreamAbi) {
          throw new Error('addTipStream function not found in TipJar ABI')
        }

        srcCalldatas.push(
          encodeFunctionData({
            abi: [addTipStreamAbi],
            functionName: 'addTipStream',
            args: [
              {
                recipient: stream.recipient,
                allocation: BigInt(stream.allocation),
                lockedUntilEpoch: BigInt(stream.minTerm),
              },
            ],
          }),
        )
      }
    }

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
      const configManagerAddress = satelliteConfig.deployedContracts.core.configurationManager
        .address as Address
      const tipJarAddress = tipJarAddresses[chainName]
      const currentChainEndpointId = satelliteConfig.common.layerZero.eID
      const chainId = getChainIdByNetwork(chainName)

      // Prepare the destination chain actions
      const dstTargets: Address[] = []
      const dstValues: bigint[] = []
      const dstCalldatas: Hex[] = []

      // Action to update ConfigurationManager on satellite chain
      dstTargets.push(configManagerAddress)
      dstValues.push(0n)
      dstCalldatas.push(
        encodeFunctionData({
          abi: [
            {
              name: 'setTipJar',
              type: 'function',
              inputs: [{ name: 'newTipJar', type: 'address' }],
              outputs: [],
              stateMutability: 'nonpayable',
            },
          ],
          functionName: 'setTipJar',
          args: [tipJarAddress],
        }),
      )

      // Add actions to set up tip streams on satellite chain
      if (tipStreamsConfig.tipStreams && tipStreamsConfig.tipStreams.length > 0) {
        for (const stream of tipStreamsConfig.tipStreams) {
          dstTargets.push(tipJarAddress)
          dstValues.push(0n)

          // Use the actual contract ABI
          const addTipStreamAbi = TipJarAbi.abi.find(
            (item) => item.type === 'function' && item.name === 'addTipStream',
          )

          if (!addTipStreamAbi) {
            throw new Error('addTipStream function not found in TipJar ABI')
          }

          dstCalldatas.push(
            encodeFunctionData({
              abi: [addTipStreamAbi],
              functionName: 'addTipStream',
              args: [
                {
                  recipient: stream.recipient,
                  allocation: BigInt(stream.allocation),
                  lockedUntilEpoch: BigInt(stream.minTerm),
                },
              ],
            }),
          )
        }
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
# TipJar Update on ${chainName}

## Summary
This cross-chain proposal updates the TipJar configuration on ${chainName} by registering the TipJar address in the ConfigurationManager and configuring tip streams with corrected allocation values.

## Actions
1. Register TipJar address (${tipJarAddress}) with ConfigurationManager
${
  tipStreamsConfig.tipStreams && tipStreamsConfig.tipStreams.length > 0
    ? `2. Configure ${tipStreamsConfig.tipStreams.length} tip streams with corrected allocations:
${tipStreamsConfig.tipStreams
  .map((stream, i) => {
    const allocationBigInt = BigInt(stream.allocation)
    const percentageValue = Number(allocationBigInt / BigInt(10 ** 16)) / 100
    const minTermSeconds = Number(stream.minTerm)
    const minTermDays = (minTermSeconds / 86400).toFixed(0)

    return `   - Stream ${i + 1}: Recipient ${stream.recipient}, Allocation ${stream.allocation} (${percentageValue}%), Min Term ${stream.minTerm} seconds (${minTermDays} days)`
  })
  .join('\n')}`
    : ''
}
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

      console.log(kleur.green(`- Added cross-chain proposal for ${chainName}`))
    }

    // Get the effective target chains based on bummer config
    const effectiveTargetChains = useBummerConfig
      ? TARGET_CHAINS.filter((chain) => chain !== 'mainnet')
      : TARGET_CHAINS

    // Create title and description for the full proposal
    const title = `SIP5.1: Multi-Chain TipJar Update`
    const description = `
# SIP5.1: Multi-Chain TipJar Update

## Summary
This proposal updates TipJar configurations across all active chains in the Lazy Summer Protocol ecosystem by registering updated TipJar instances with each chain's ConfigurationManager and setting up proper tip streams.

## Motivation
Properly configured TipJars are essential for the protocol's revenue distribution mechanisms. This proposal corrects the tipstream allocations that were set too low during the initial launch, ensuring that revenue distribution operates as intended according to governance-approved parameters.

Newly deployed TipJar contracts:
${effectiveTargetChains.map((chain) => `- ${chain}: ${tipJarAddresses[chain]}`).join('\n')}

## Specifications

### Actions
1. On ${HUB_CHAIN_NAME}: 
   - Register TipJar address with ConfigurationManager
   - Configure tip streams with corrected allocation values
${TARGET_CHAINS.filter(filterTargetChains)
  .map(
    (chain) => `2. Send cross-chain proposal to ${chain} to:
   - Register TipJar address with ConfigurationManager
   - Configure tip streams with corrected allocation values`,
  )
  .join('\n')}

### Tip Streams Configuration
${
  tipStreamsConfig.tipStreams && tipStreamsConfig.tipStreams.length > 0
    ? tipStreamsConfig.tipStreams
        .map((stream, i) => {
          const allocationBigInt = BigInt(stream.allocation)
          const percentageValue = Number(allocationBigInt / BigInt(10 ** 18))
          const minTermSeconds = Number(stream.minTerm)
          const minTermDays = (minTermSeconds / 86400).toFixed(2)

          return `- Stream ${i + 1}: Recipient ${stream.recipient}, Allocation ${stream.allocation} (${percentageValue}%), Min Term ${stream.minTerm} seconds (${minTermDays} days)`
        })
        .join('\n')
    : 'No tip streams configured.'
}
`.trim()

    // Create action summary for better display
    const actionSummary = [
      `Update TipJar on ${HUB_CHAIN_NAME}`,
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
      `${useBummerConfig ? 'test_tipjar' : 'tipjar'}_proposal_${timestamp}.json`,
    )

    console.log(kleur.cyan('Creating governance proposal with the following actions:'))
    console.log(kleur.yellow(`- Update TipJar on ${HUB_CHAIN_NAME}`))
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

    console.log(kleur.green('✅ Successfully created multi-chain TipJar governance proposal'))
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
 * @param {Record<string, Address>} tipJarAddresses - The TipJar addresses for each chain.
 * @param {TipStreamsConfig} tipStreamsConfig - The tip streams configuration.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmProposal(
  tipJarAddresses: Record<string, Address>,
  tipStreamsConfig: TipStreamsConfig,
): Promise<boolean> {
  console.log(kleur.cyan().bold('\nSummary of TipJar Governance Proposal:'))
  console.log(kleur.yellow('This will create a multi-chain proposal with the following details:'))

  // Display TipJar addresses
  console.log(kleur.yellow('TipJar Addresses:'))
  for (const chain of TARGET_CHAINS) {
    console.log(kleur.yellow(`  ${chain}: ${tipJarAddresses[chain]}`))
  }

  // Display tip streams
  if (tipStreamsConfig.tipStreams && tipStreamsConfig.tipStreams.length > 0) {
    console.log(kleur.yellow(`Tip Streams (${tipStreamsConfig.tipStreams.length}):`))
    tipStreamsConfig.tipStreams.forEach((stream, index) => {
      console.log(kleur.yellow(`  ${index + 1}. Recipient: ${stream.recipient}`))
      console.log(kleur.yellow(`     Allocation: ${stream.allocation}`))
      // Format allocation as percentage (1e18 = 1%)
      const allocationBigInt = BigInt(stream.allocation)
      const percentageValue = Number(allocationBigInt / BigInt(10 ** 18))
      console.log(kleur.yellow(`     Allocation (readable): ${percentageValue}%`))
      console.log(kleur.yellow(`     Min Term: ${stream.minTerm} seconds`))
    })
  } else {
    console.log(kleur.yellow('No tip streams configured.'))
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
setupTipJars().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})

export { setupTipJars }
