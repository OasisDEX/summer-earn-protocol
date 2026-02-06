import hre from 'hardhat'
import kleur from 'kleur'
import path from 'node:path'
import prompts from 'prompts'
import { Address, createPublicClient, encodeFunctionData, Hex, http } from 'viem'
import { BaseConfig } from '../../types/config-types'
import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { getChainIdByNetwork } from '../helpers/get-chainid'
import { getSipMinorNumber } from '../helpers/get-sip-minor-number'
import { hashDescription } from '../helpers/hash-description'
import { constructLzOptions } from '../helpers/layerzero-options'
import { promptForConfigType } from '../helpers/prompt-helpers'
import { createGovernanceProposal } from '../helpers/proposal-helpers'
import { SUPPORTED_CHAINS, SupportedChain } from '../helpers/chain'
import { CHAIN_CONFIG_MAP, RPC_URL_MAP } from '../common/chain-config-map'

/**
 * Creates a multi-chain governance proposal to set the raft address on
 * newly deployed raft contracts on Base, Arbitrum, Sonic and Mainnet.
 */
async function setupRaft() {
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
  ) as BaseConfig

  // Load configurations for satellite chains
  const satelliteConfigs: Record<string, BaseConfig> = {}
  for (const chain of SUPPORTED_CHAINS.filter(filterTargetChains)) {
    satelliteConfigs[chain] = getConfigByNetwork(
      chain,
      { common: true, core: true, gov: true },
      useBummerConfig,
    ) as BaseConfig
  }

  // Display chains being targeted based on bummer config
  const effectiveTargetChains = useBummerConfig
    ? SUPPORTED_CHAINS.filter((chain) => chain !== 'mainnet')
    : SUPPORTED_CHAINS

  // Confirm network selection
  const confirmNetworks = await prompts({
    type: 'confirm',
    name: 'continue',
    message: `This will create a multi-chain governance proposal to add raft to configuration manager on: ${effectiveTargetChains.join(
      ', ',
    )}. Continue?`,
    initial: true,
  })

  if (!confirmNetworks.continue) {
    console.log(kleur.red('Operation cancelled by user.'))
    return
  }

  // Get raft addresses from config files
  const raftAddresses: Record<string, Address> = {}
  console.log(kleur.cyan('Using raft addresses from config:'))

  // For hub chain
  raftAddresses[HUB_CHAIN_NAME] = hubConfig.deployedContracts.core.raft.address as Address
  console.log(kleur.yellow(`  ${HUB_CHAIN_NAME}: ${raftAddresses[HUB_CHAIN_NAME]}`))

  // For satellite chains
  for (const chain of SUPPORTED_CHAINS.filter(filterTargetChains)) {
    raftAddresses[chain] = satelliteConfigs[chain].deployedContracts.core.raft.address as Address
    console.log(kleur.yellow(`  ${chain}: ${raftAddresses[chain]}`))
  }

  // Get previous raft addresses if needed
  const previousRaftAddresses: Record<string, Address> = {}

  const configurationManagerContractAddress = hubConfig.deployedContracts.core.configurationManager
    .address as Address
  const hubPublicClient = await hre.viem.getPublicClient()

  const previousHubRaftAddress = await hubPublicClient.readContract({
    address: configurationManagerContractAddress,
    abi: [
      {
        name: 'raft',
        type: 'function',
        inputs: [],
        outputs: [{ name: 'raft', type: 'address' }],
      },
    ],
    functionName: 'raft',
  })

  if (previousHubRaftAddress) {
    previousRaftAddresses[HUB_CHAIN_NAME] = previousHubRaftAddress as Address
    console.log(kleur.yellow(`  ${HUB_CHAIN_NAME}: ${previousRaftAddresses[HUB_CHAIN_NAME]}`))
  }

  // For satellite chains
  for (const chain of SUPPORTED_CHAINS.filter(filterTargetChains)) {
    const satellitePublicClient = createPublicClient({
      chain: CHAIN_CONFIG_MAP[chain],
      transport: http(RPC_URL_MAP[chain]),
    })
    const satelliteConfigurationManagerAddress = satelliteConfigs[chain].deployedContracts.core
      .configurationManager.address as Address
    const previousSatelliteRaftAddress = await satellitePublicClient.readContract({
      address: satelliteConfigurationManagerAddress,
      abi: [
        {
          name: 'raft',
          type: 'function',
          inputs: [],
          outputs: [{ name: 'raft', type: 'address' }],
        },
      ],
      functionName: 'raft',
    })

    if (previousSatelliteRaftAddress) {
      previousRaftAddresses[chain] = previousSatelliteRaftAddress as Address
      console.log(kleur.yellow(`  ${chain}: ${previousRaftAddresses[chain]}`))
    }
  }

  // Display summary and ask for confirmation
  if (await confirmProposal(raftAddresses, previousRaftAddresses)) {
    // Create and save the multi-chain governance proposal
    await createMultiChainRaftProposal(
      raftAddresses,
      previousRaftAddresses,
      hubConfig,
      satelliteConfigs,
      useBummerConfig,
    )
  } else {
    console.log(kleur.red().bold('Operation cancelled by user.'))
  }
}

/**
 * Creates a multi-chain governance proposal for setting the raft address on the ConfigurationManager contract.
 * @param {Record<string, Address>} raftAddresses - The raft addresses for each chain.
 * @param {Record<string, Address>} previousRaftAddresses - The previous raft addresses to revoke role from.
 * @param {BaseConfig} hubConfig - The configuration for the hub chain.
 * @param {Record<string, BaseConfig>} satelliteConfigs - The configurations for the satellite chains.
 * @param {boolean} useBummerConfig - Whether to use bummer config.
 */
async function createMultiChainRaftProposal(
  raftAddresses: Record<string, Address>,
  previousRaftAddresses: Record<string, Address>,
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

  // Get SIP minor number
  const sipMinorNumber = await getSipMinorNumber()

  try {
    // Get the hub chain governor address
    const hubGovernorAddress = hubConfig.deployedContracts.govV2.summerGovernor.address as Address

    // Prepare actions for the hub chain (Base)
    const srcTargets: Address[] = []
    const srcValues: bigint[] = []
    const srcCalldatas: Hex[] = []

    // 1. Prepare hub chain actions (Base)
    console.log(kleur.yellow('Preparing hub chain actions for Base...'))

    // Get the Configuration Manager address
    const hubConfigurationManagerAddress = hubConfig.deployedContracts.core.configurationManager
      .address as Address

    // Action to set raft address on Base
    srcTargets.push(hubConfigurationManagerAddress)
    srcValues.push(0n)
    srcCalldatas.push(
      encodeFunctionData({
        abi: [
          {
            name: 'setRaft',
            type: 'function',
            inputs: [{ name: 'account', type: 'address' }],
            outputs: [],
            stateMutability: 'nonpayable',
          },
        ],
        functionName: 'setRaft',
        args: [raftAddresses[HUB_CHAIN_NAME]],
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
    for (const chainName of SUPPORTED_CHAINS.filter(filterTargetChains)) {
      const satelliteConfig = satelliteConfigs[chainName]
      const satelliteConfigurationManagerAddress = satelliteConfig.deployedContracts.core
        .configurationManager.address as Address
      const raftAddress = raftAddresses[chainName]
      const currentChainEndpointId = satelliteConfig.common.layerZero.eID
      const chainId = getChainIdByNetwork(chainName)

      // Prepare the destination chain actions
      const dstTargets: Address[] = []
      const dstValues: bigint[] = []
      const dstCalldatas: Hex[] = []

      // Action to set raft on satellite chain
      dstTargets.push(satelliteConfigurationManagerAddress)
      dstValues.push(0n)
      dstCalldatas.push(
        encodeFunctionData({
          abi: [
            {
              name: 'setRaft',
              type: 'function',
              inputs: [{ name: 'account', type: 'address' }],
              outputs: [],
              stateMutability: 'nonpayable',
            },
          ],
          functionName: 'setRaft',
          args: [raftAddress],
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
# Raft address update on ${chainName}

## Summary
This cross-chain proposal updates the raft address on ${chainName}.

## Actions
1. Set raft address on ${chainName} to ${raftAddress} via the ConfigurationManager
      `.trim()

      // Add cross-chain proposal action to the source chain actions
      const ESTIMATED_GAS = 500000n
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
      ? SUPPORTED_CHAINS.filter((chain) => chain !== 'mainnet')
      : SUPPORTED_CHAINS

    // Create title and description for the full proposal
    const sipNumber = sipMinorNumber !== undefined ? `SIP5.${sipMinorNumber}` : 'SIP5'
    const title = `${sipNumber}: Multi-Chain Raft Address Update`
    const description = `
# ${sipNumber}: Multi-Chain Raft Address Update

## Summary
This proposal updates the raft address on all active chains in the Lazy Summer Protocol ecosystem.

## Motivation
The raft contract is used to handle reward token auctions. It updates the Raft contract to handle tokens with self transfer functionality blocked.

Newly deployed raft contracts:
${effectiveTargetChains.map((chain) => `- ${chain}: ${raftAddresses[chain]}`).join('\n')}

## Specifications

### Actions
1. On ${HUB_CHAIN_NAME}: 
   - Set raft address on ${HUB_CHAIN_NAME} to ${raftAddresses[HUB_CHAIN_NAME]}
${SUPPORTED_CHAINS.filter(filterTargetChains)
  .map(
    (chain) => `2. Send cross-chain proposal to ${chain} to:
   - Set raft address on ${chain} to ${raftAddresses[chain]}`,
  )
  .join('\n')}

## Technical Details
The raft contract is used to handle reward token auctions. It updates the Raft contract to handle tokens with self transfer functionality blocked.
`.trim()

    // Create action summary for better display
    const actionSummary = [
      `Set raft address on ${HUB_CHAIN_NAME} to ${raftAddresses[HUB_CHAIN_NAME]}`,
      ...SUPPORTED_CHAINS.filter(filterTargetChains).map(
        (chain) =>
          `Send cross-chain proposal to ${chain} to set raft address on ${chain} to ${raftAddresses[chain]}`,
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
      `${useBummerConfig ? 'test_raft' : 'raft'}_proposal_${timestamp}.json`,
    )

    console.log(kleur.cyan('Creating governance proposal with the following actions:'))
    console.log(
      kleur.yellow(`- Set raft address on ${HUB_CHAIN_NAME} to ${raftAddresses[HUB_CHAIN_NAME]}`),
    )
    for (const chain of SUPPORTED_CHAINS.filter(filterTargetChains)) {
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

    console.log(kleur.green('✅ Successfully created multi-chain raft governance proposal'))
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
 * @param {Record<string, Address>} raftAddresses - The raft addresses for each chain.
 * @param {Record<string, Address>} previousRaftAddresses - The previous raft addresses to revoke role from.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmProposal(
  raftAddresses: Record<string, Address>,
  previousRaftAddresses: Record<string, Address>,
): Promise<boolean> {
  console.log(kleur.cyan().bold('\nSummary of raft Governance Proposal:'))
  console.log(kleur.yellow('This will create a multi-chain proposal with the following details:'))

  // Display raft addresses
  console.log(kleur.yellow('raft Addresses to set raft address:'))
  for (const chain in raftAddresses) {
    console.log(kleur.yellow(`  ${chain}: ${raftAddresses[chain]}`))
  }

  // Display previous raft addresses if any
  if (Object.keys(previousRaftAddresses).length > 0) {
    console.log(kleur.yellow('\nPrevious raft Addresses to revoke raft address from:'))
    for (const chain in previousRaftAddresses) {
      console.log(kleur.yellow(`  ${chain}: ${previousRaftAddresses[chain]}`))
    }
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
setupRaft().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})

export { setupRaft }
